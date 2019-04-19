using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using YamlDotNet.Serialization;

namespace DockerGenerator
{
	class Program
	{

		static void Main(string[] args)
		{
			var root = Environment.GetEnvironmentVariable("INSIDE_CONTAINER") == "1" ? FindRoot("app")
				: Path.GetFullPath(Path.Combine(FindRoot("docker-compose-generator"), ".."));

			var composition = DockerComposition.FromEnvironmentVariables();
			Console.WriteLine("Crypto: " + string.Join(", ", composition.SelectedCryptos.ToArray()));
			Console.WriteLine("Lightning: " + composition.SelectedLN);
			Console.WriteLine("ReverseProxy: " + composition.SelectedProxy);
			var generatedLocation = Path.GetFullPath(Path.Combine(root, "Generated"));

			var name = Environment.GetEnvironmentVariable("BTCPAYGEN_SUBNAME");
			name = string.IsNullOrEmpty(name) ? "generated" : name;
			new Program().Run(composition, name, generatedLocation);
		}

		private void Run(DockerComposition composition, string name, string output)
		{
			var fragmentLocation = Environment.GetEnvironmentVariable("INSIDE_CONTAINER") == "1" ? "app" : "docker-compose-generator";
			fragmentLocation = FindRoot(fragmentLocation);
			fragmentLocation = Path.GetFullPath(Path.Combine(fragmentLocation, "docker-fragments"));

			var fragments = new HashSet<string>();
			switch (composition.SelectedProxy)
			{
				case "nginx":
					fragments.Add("nginx-https");
					fragments.Add("nginx");
					fragments.Add("btcpayserver-nginx");
					break;
				case "traefik":
					fragments.Add("traefik");
					fragments.Add("traefik-labels");
					break;
				case "no-reverseproxy":
				case "none":
				case "":
					fragments.Add("btcpayserver-noreverseproxy");
					break;
			}
			fragments.Add("btcpayserver");
			fragments.Add("opt-add-tor");
			fragments.Add("nbxplorer");
			fragments.Add("postgres");
			foreach (var crypto in CryptoDefinition.GetDefinitions())
			{
				if (!composition.SelectedCryptos.Contains(crypto.Crypto))
					continue;

				fragments.Add(crypto.CryptoFragment);
				if (composition.SelectedLN == "clightning" && crypto.CLightningFragment != null)
				{
					fragments.Add(crypto.CLightningFragment);
				}
				if (composition.SelectedLN == "lnd" && crypto.LNDFragment != null)
				{
					fragments.Add(crypto.LNDFragment);
				}
				if (composition.SelectedLN == "eclair" && crypto.EclairFragment != null)
				{
					fragments.Add(crypto.EclairFragment);
				}
			}

			foreach (var fragment in composition.AdditionalFragments)
			{
				fragments.Add(fragment.Trim());
			}
			fragments = fragments.Where(s => !composition.ExcludeFragments.Contains(s)).ToHashSet();
			var def = new DockerComposeDefinition(name, fragments);
			def.FragmentLocation = fragmentLocation;
			def.BuildOutputDirectory = output;
			def.Build();
		}

		private static string FindRoot(string rootDirectory)
		{
			string directory = Directory.GetCurrentDirectory();
			int i = 0;
			while (true)
			{
				if (i > 10)
					throw new DirectoryNotFoundException(rootDirectory);
				if (directory.EndsWith(rootDirectory))
					return directory;
				directory = Path.GetFullPath(Path.Combine(directory, ".."));
				i++;
			}
		}
	}
}
