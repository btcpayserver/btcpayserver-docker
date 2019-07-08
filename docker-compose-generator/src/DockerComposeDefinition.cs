using System;
using System.Linq;
using System.Collections.Generic;
using System.Text;
using YamlDotNet.RepresentationModel;
using YamlDotNet.Serialization;
using System.IO;

namespace DockerGenerator
{
	public class DockerComposeDefinition
	{
		public HashSet<string> Fragments
		{
			get; set;
		}
		private string _Name;

		public DockerComposeDefinition(string name, HashSet<string> fragments)
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

			Console.WriteLine($"With fragments:");
			foreach (var fragment in Fragments.ToList())
			{
				var fragmentPath = GetFragmentLocation(fragment);
				if (!File.Exists(fragmentPath))
				{
					Console.WriteLine($"\t{fragment} not found in {fragmentPath}, ignoring...");
					Fragments.Remove(fragment);
				}
				else
				{
					Console.WriteLine($"\t{fragment}");
				}
			}

			var services = new List<KeyValuePair<YamlNode, YamlNode>>();
			var volumes = new List<KeyValuePair<YamlNode, YamlNode>>();
			var networks = new List<KeyValuePair<YamlNode, YamlNode>>();

			foreach (var doc in Fragments.Select(f => ParseDocument(f)))
			{
				if (doc.Children.ContainsKey("services") && doc.Children["services"] is YamlMappingNode fragmentServicesRoot)
				{
					services.AddRange(fragmentServicesRoot.Children);
				}

				if (doc.Children.ContainsKey("volumes") && doc.Children["volumes"] is YamlMappingNode fragmentVolumesRoot)
				{
					volumes.AddRange(fragmentVolumesRoot.Children);
				}
				if (doc.Children.ContainsKey("networks") && doc.Children["networks"] is YamlMappingNode fragmentNetworksRoot)
				{
					networks.AddRange(fragmentNetworksRoot.Children);
				}
			}


			YamlMappingNode output = new YamlMappingNode();
			output.Add("version", new YamlScalarNode("3") { Style = YamlDotNet.Core.ScalarStyle.DoubleQuoted });
			output.Add("services", new YamlMappingNode(Merge(services)));
			output.Add("volumes", new YamlMappingNode(volumes));
			output.Add("networks", new YamlMappingNode(networks));


			var dockerImages = ((YamlMappingNode)output["services"]).Children.Select(kv => kv.Value["image"].ToString()).ToList();
			dockerImages.Add("btcpayserver/docker-compose-builder:1.23.2");
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
			Console.WriteLine();
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

		private YamlMappingNode ParseDocument(string fragment)
		{
			var input = new StringReader(File.ReadAllText(GetFragmentLocation(fragment)));
			YamlStream stream = new YamlStream();
			stream.Load(input);
			return (YamlMappingNode)stream.Documents[0].RootNode;
		}

		private string GetFragmentLocation(string fragment)
		{
			return Path.Combine(FragmentLocation, $"{fragment}.yml");
		}
	}
}
