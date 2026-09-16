using System;
using System.Linq;
using System.Collections.Generic;
using System.Text;
using YamlDotNet.RepresentationModel;
using YamlDotNet.Serialization;
using System.IO;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace DockerGenerator
{
	public class DockerComposeDefinition
	{
		public HashSet<FragmentName> Fragments
		{
			get; set;
		}
		private string _Name;

		public DockerComposeDefinition(string name, HashSet<FragmentName> fragments)
		{
			Fragments = fragments;
			_Name = name;
		}

		public string FragmentLocation
		{
			get; set;
		}
		public string BuildOutputDirectory
		{
			get; set;
		}
		public HashSet<FragmentName> ExcludeFragments { get; internal set; }

		public string GetFilePath()
		{
			return GetFilePath($"docker-compose.{_Name}.yml");
		}
		public string GetFilePath(string fileName)
		{
			return Path.Combine(BuildOutputDirectory, fileName);
		}
		public void Build()
		{
			Console.WriteLine($"Generating {GetFilePath()}");
			var deserializer = new DeserializerBuilder().Build();
			var serializer = new SerializerBuilder().Build();
			var (processedFragments, fragmentsNotFound) = ResolveFragments();
			var exclusives = new List<(FragmentName FragmentName, string Exclusivity)>();
			var incompatibles = new List<(FragmentName FragmentName, string Exclusivity)>();

			foreach (var o in processedFragments.Select(f => (f, ParseDocument(f))).ToList())
			{
				var doc = o.Item2;
				var fragment = o.f;
				if (doc.Children.ContainsKey("exclusive") && doc.Children["exclusive"] is YamlSequenceNode fragmentExclusiveRoot)
				{
					foreach (var node in fragmentExclusiveRoot)
					{
						exclusives.Add((fragment, node.ToString()));
					}
				}
				if (doc.Children.ContainsKey("incompatible") && doc.Children["incompatible"] is YamlSequenceNode fragmentIncompatibleRoot)
				{
					foreach (var node in fragmentIncompatibleRoot)
					{
						incompatibles.Add((fragment, node.ToString()));
					}
				}
			}
			var exclusiveConflict = exclusives.GroupBy(e => e.Exclusivity)
			.Where(e => e.Count() != 1)
			.FirstOrDefault();
			if (exclusiveConflict != null)
				throw new YamlBuildException($"The fragments {String.Join(", ", exclusiveConflict.Select(e => e.FragmentName))} can't be used simultaneously (group '{exclusiveConflict.Key}')");

			var groups = exclusives.ToDictionary(e => e.Exclusivity, e => e.FragmentName);
			var incompatible = incompatibles
								.Select(i => groups.TryGetValue(i.Exclusivity, out _) ? (i.FragmentName, i.Exclusivity) : (null, null))
								.Where(i => i.Exclusivity != null)
								.FirstOrDefault();
			if (incompatible.Exclusivity != null)
				throw new YamlBuildException($"The fragment {incompatible.FragmentName} is incompatible with '{incompatible.Exclusivity}'");

			Console.WriteLine($"Selected fragments:");
			foreach (var fragment in processedFragments)
			{
				Console.WriteLine($"\t{fragment}");
			}
			foreach (var fragment in fragmentsNotFound)
			{
				var fragmentPath = GetFragmentLocation(fragment);
				ConsoleUtils.WriteLine($"\t{fragment} not found in {fragmentPath}, ignoring...", ConsoleColor.Yellow);
			}

			var services = new List<KeyValuePair<YamlNode, YamlNode>>();
			var volumes = new List<KeyValuePair<YamlNode, YamlNode>>();
			var configs = new List<KeyValuePair<YamlNode, YamlNode>>();
			var networks = new List<KeyValuePair<YamlNode, YamlNode>>();
			var secrets = new List<KeyValuePair<YamlNode, YamlNode>>();
			var requiredRoutes = new HashSet<string>(StringComparer.Ordinal);
			var optionalRoutes = new HashSet<string>(StringComparer.Ordinal);
			foreach (var o in processedFragments.Select(f => (f, ParseDocument(f))).ToList())
			{
				var doc = o.Item2;
				var fragment = o.f;
				if (doc.Children.ContainsKey("services") && doc.Children["services"] is YamlMappingNode fragmentServicesRoot)
				{
					services.AddRange(fragmentServicesRoot.Children);
				}
				if (doc.Children.ContainsKey("volumes") && doc.Children["volumes"] is YamlMappingNode fragmentVolumesRoot)
				{
					volumes.AddRange(fragmentVolumesRoot.Children);
				}
				if (doc.Children.ContainsKey("configs") && doc.Children["configs"] is YamlMappingNode fragmentConfigsRoot)
				{
					configs.AddRange(fragmentConfigsRoot.Children);
				}
				if (doc.Children.ContainsKey("networks") && doc.Children["networks"] is YamlMappingNode fragmentNetworksRoot)
				{
					networks.AddRange(fragmentNetworksRoot.Children);
				}
				if (doc.Children.ContainsKey("secrets") && doc.Children["secrets"] is YamlMappingNode fragmentSecretsRoot)
				{
					secrets.AddRange(fragmentSecretsRoot.Children);
				}
				AddRoutes(doc, "required-routes", requiredRoutes, fragment);
				AddRoutes(doc, "optional-routes", optionalRoutes, fragment);
			}
			var conflictingRoute = requiredRoutes.Intersect(optionalRoutes).FirstOrDefault();
			if (conflictingRoute != null)
				throw new YamlBuildException($"Route {conflictingRoute} cannot be both required and optional");

			YamlMappingNode output = new YamlMappingNode();
			output.Add("services", new YamlMappingNode(Merge(services)));
			output.Add("volumes", new YamlMappingNode(volumes));
			output.Add("configs", new YamlMappingNode(configs));
			output.Add("networks", new YamlMappingNode(networks));
			output.Add("secrets", new YamlMappingNode(secrets));
			PostProcess(output);
			var secretFiles = secrets
				.Select(s => s.Value)
				.OfType<YamlMappingNode>()
				.Where(s => s.Children.TryGetValue("file", out var file) && file is YamlScalarNode)
				.Select(s => ((YamlScalarNode)s.Children["file"]).Value)
				.Where(f => !string.IsNullOrWhiteSpace(f))
				.Distinct(StringComparer.Ordinal)
				.OrderBy(f => f, StringComparer.Ordinal)
				.ToArray();

			var dockerImages = ((YamlMappingNode)output["services"]).Children.Select(kv => kv.Value["image"].ToString()).ToList();
			dockerImages.Add("docker/compose-bin:v2.40.3");
			dockerImages.Add("btcpayserver/docker-compose-generator:latest");
			StringBuilder pullImageSh = new StringBuilder();
			pullImageSh.Append($"#!/bin/bash\n\n");
			pullImageSh.Append($"# This script is automatically generated via the docker-compose generator and can be use to pull all required docker images \n");
			foreach (var image in dockerImages)
			{
				pullImageSh.Append($"docker pull $BTCPAY_DOCKER_PULL_FLAGS \"{image}\"\n");
			}
			var outputFile = GetFilePath("pull-images.sh");
			File.WriteAllText(outputFile, pullImageSh.ToString());
			Console.WriteLine($"Generated {outputFile}");

			StringBuilder saveImages = new StringBuilder();
			saveImages.Append($"#!/bin/bash\n\n");
			saveImages.Append($"# This script is automatically generated via the docker-compose generator and can be use to save the docker images in an archive \n");
			saveImages.Append($"# ./save-images.sh output.tar \n");
			saveImages.Append($"docker save -o \"$1\" \\\n {string.Join(" \\\n", dockerImages.Select(o => $"\"{o}\""))}");
			outputFile = GetFilePath("save-images.sh");
			File.WriteAllText(outputFile, saveImages.ToString());
			Console.WriteLine($"Generated {outputFile}");

			var result = serializer.Serialize(output);
			outputFile = GetFilePath();
			File.WriteAllText(outputFile, result.Replace("''", ""));
			Console.WriteLine($"Generated {outputFile}");

			var manifest = new
			{
				requiredRoutes = requiredRoutes.OrderBy(r => r, StringComparer.Ordinal).ToArray(),
				optionalRoutes = optionalRoutes.OrderBy(r => r, StringComparer.Ordinal).ToArray(),
				fragments = processedFragments.Select(f => f.Name).OrderBy(f => f, StringComparer.Ordinal).ToArray(),
				secrets = secretFiles
			};
			outputFile = GetFilePath("manifest.json");
			File.WriteAllText(outputFile, JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true }));
			Console.WriteLine($"Generated {outputFile}");
			Console.WriteLine();
		}

		private (HashSet<FragmentName> Processed, HashSet<FragmentName> NotFound) ResolveFragments()
		{
			var rootFragments = Fragments.Where(NotExcluded).ToHashSet();
			var declaredExclusions = new HashSet<FragmentName>();
			var seenExclusionSets = new HashSet<string>(StringComparer.Ordinal);

			while (true)
			{
				var exclusionSignature = String.Join("\n", declaredExclusions.OrderBy(f => f.Name).Select(f => f.Name));
				if (!seenExclusionSets.Add(exclusionSignature))
					throw new YamlBuildException("Fragment exclusions contain a cycle and cannot be resolved");

				var selectedFragments = rootFragments.ToHashSet();
				var mandatoryFragments = rootFragments.ToHashSet();
				var processedFragments = new HashSet<FragmentName>();
				var fragmentsNotFound = new HashSet<FragmentName>();
				var unprocessedFragments = rootFragments.ToHashSet();
				var exclusions = new List<(FragmentName Fragment, FragmentName Excluded)>();
				var excludedRequirements = new List<(FragmentName Fragment, FragmentName Required)>();

				while (unprocessedFragments.Count != 0)
				{
					var fragment = unprocessedFragments.First();
					unprocessedFragments.Remove(fragment);

					if (!File.Exists(GetFragmentLocation(fragment)))
					{
						fragmentsNotFound.Add(fragment);
						continue;
					}

					var doc = ParseDocument(fragment);
					foreach (var excluded in ReadExcludedFragments(doc, fragment))
					{
						if (excluded.Equals(fragment))
							throw new YamlBuildException($"Fragment {fragment} cannot exclude itself");
						exclusions.Add((fragment, excluded));
					}

					if (doc.Children.ContainsKey("required") && doc.Children["required"] is YamlSequenceNode fragmentRequireRoot)
					{
						foreach (var node in fragmentRequireRoot)
						{
							var required = new FragmentName(node.ToString());
							if (ExcludeFragments.Contains(required))
							{
								excludedRequirements.Add((fragment, required));
								continue;
							}
							mandatoryFragments.Add(required);
							if (selectedFragments.Add(required))
								unprocessedFragments.Add(required);
						}
					}

					if (doc.Children.ContainsKey("recommended") && doc.Children["recommended"] is YamlSequenceNode fragmentRecommendedRoot)
					{
						foreach (var node in fragmentRecommendedRoot)
						{
							var recommended = new FragmentName(node.ToString());
							if (!ExcludeFragments.Contains(recommended) &&
								!declaredExclusions.Contains(recommended) &&
								selectedFragments.Add(recommended))
								unprocessedFragments.Add(recommended);
						}
					}

					processedFragments.Add(fragment);
				}

				var nextDeclaredExclusions = exclusions.Select(e => e.Excluded).ToHashSet();
				if (declaredExclusions.SetEquals(nextDeclaredExclusions))
				{
					var excludedRequirement = excludedRequirements.FirstOrDefault();
					if (excludedRequirement.Fragment != null)
						throw new YamlBuildException($"You excluded fragment {excludedRequirement.Required} but it is required by {excludedRequirement.Fragment}");
					var conflict = exclusions.FirstOrDefault(e => mandatoryFragments.Contains(e.Excluded));
					if (conflict.Fragment != null)
						throw new YamlBuildException($"Fragment {conflict.Fragment} excludes {conflict.Excluded}, but {conflict.Excluded} is explicitly selected or required");
					return (processedFragments, fragmentsNotFound);
				}

				declaredExclusions = nextDeclaredExclusions;
			}
		}

		private IEnumerable<FragmentName> ReadExcludedFragments(YamlMappingNode document, FragmentName fragment)
		{
			if (!document.Children.TryGetValue("excluded", out var excludedNode))
				yield break;
			if (excludedNode is not YamlSequenceNode excludedSequence)
				throw new YamlBuildException($"excluded in fragment {fragment} must be a sequence");

			foreach (var node in excludedSequence)
			{
				if (node is not YamlScalarNode scalar || string.IsNullOrWhiteSpace(scalar.Value))
					throw new YamlBuildException($"excluded in fragment {fragment} contains an invalid fragment name");
				if (scalar.Value.Trim().EndsWith(".yml", StringComparison.OrdinalIgnoreCase))
					throw new YamlBuildException($"excluded in fragment {fragment} contains an invalid fragment name");
				var excluded = new FragmentName(scalar.Value);
				if (!Regex.IsMatch(excluded.Name, "^[a-z0-9][a-z0-9._-]*$"))
					throw new YamlBuildException($"excluded in fragment {fragment} contains an invalid fragment name");
				yield return excluded;
			}
		}

		private void AddRoutes(YamlMappingNode document, string key, HashSet<string> routes, FragmentName fragment)
		{
			if (!document.Children.TryGetValue(key, out var routeNode))
				return;
			if (routeNode is not YamlSequenceNode routeSequence)
				throw new YamlBuildException($"{key} in fragment {fragment} must be a sequence");
			foreach (var route in routeSequence)
			{
				if (route is not YamlScalarNode routeScalar ||
					string.IsNullOrWhiteSpace(routeScalar.Value) ||
					!Regex.IsMatch(routeScalar.Value, "^[a-z0-9][a-z0-9-]*$"))
					throw new YamlBuildException($"{key} in fragment {fragment} contains an invalid route alias");
				var routeName = routeScalar.Value;
				routes.Add(routeName);
			}
		}

		private bool NotExcluded(FragmentName arg)
		{
			return !ExcludeFragments.Contains(arg);
		}

		private void PostProcess(YamlMappingNode output)
		{
			new BuildTimeVariableVisitor().Visit(output);
		}

		private KeyValuePair<YamlNode, YamlNode>[] Merge(List<KeyValuePair<YamlNode, YamlNode>> services)
		{
			return services
				.GroupBy(s => s.Key.ToString(), s => s.Value)
				.Select(group =>
					(GroupName: group.Key,
					 MainNode: group.OfType<YamlMappingNode>().SingleOrDefault(n => n.Children.ContainsKey("image")),
					 MergedNodes: group.OfType<YamlMappingNode>().Where(n => !n.Children.ContainsKey("image"))))
				.Where(_ => _.MainNode != null)
				.Select(_ =>
				{
					foreach (var node in _.MergedNodes)
					{
						foreach (var child in node)
						{
							var childValue = child.Value;
							if (!_.MainNode.Children.TryGetValue(child.Key, out var mainChildValue))
							{
								mainChildValue = child.Value;
								_.MainNode.Add(child.Key, child.Value);
							}
							else if (childValue is YamlMappingNode childMapping && mainChildValue is YamlMappingNode mainChildMapping)
							{
								foreach (var leaf in childMapping)
								{
									if (mainChildMapping.Children.TryGetValue(leaf.Key, out var mainLeaf))
									{
										if (leaf.Value is YamlScalarNode leafScalar && mainLeaf is YamlScalarNode leafMainScalar)
										{
											var eof = EOF(leafMainScalar.Value) ?? EOF(leaf.Value.ToString());
											if (eof != null)
											{
												leafMainScalar.Value = leafMainScalar.Value + eof + leaf.Value;
											}
											else
											{
												leafMainScalar.Value = leafMainScalar.Value + "," + leaf.Value;
											}
										}
									}
									else
									{
										mainChildMapping.Add(leaf.Key, leaf.Value);
									}
								}
							}
							else if (childValue is YamlSequenceNode childSequence && mainChildValue is YamlSequenceNode mainSequence)
							{
								foreach (var c in childSequence.Children)
								{
									mainSequence.Add(c);
								}
							}
						}
					}
					return new KeyValuePair<YamlNode, YamlNode>(_.GroupName, _.MainNode);
				}).ToArray();
		}

		private string EOF(string value)
		{
			if (value.Contains("\r\n", StringComparison.OrdinalIgnoreCase))
				return "\r\n";
			if (value.Contains("\n", StringComparison.OrdinalIgnoreCase))
				return "\n";
			return null;
		}

		private YamlMappingNode ParseDocument(FragmentName fragment)
		{
			var input = new StringReader(File.ReadAllText(GetFragmentLocation(fragment)));
			YamlStream stream = new YamlStream();
			stream.Load(input);
			return (YamlMappingNode)stream.Documents[0].RootNode;
		}

		private string GetFragmentLocation(FragmentName fragment)
		{
			return Path.Combine(FragmentLocation, $"{fragment.Name}.yml");
		}
	}
}
