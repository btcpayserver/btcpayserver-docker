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

			if(args.Any(a => a == "pregen"))
			{
				var productionLocation = Path.GetFullPath(Path.Combine(root, "Production"));
				var testLocation = Path.GetFullPath(Path.Combine(root, "Production-NoReverseProxy"));

				foreach(var proxy in new[] { "nginx", "no-reverseproxy" })
				{
					foreach(var lightning in new[] { "clightning", "" })
					{
						foreach(var btc in new[] { "btc", "" })
						{
							foreach(var ltc in new[] { "ltc", "" })
							{
								if(btc == "" && ltc == "")
									continue;
								string name = $"{btc}-{ltc}-{lightning}".Replace("--", "-");
								if(name.EndsWith("-"))
									name = name.Substring(0, name.Length - 1);
								if(name.StartsWith("-"))
									name = name.Substring(1, name.Length - 1);
								var composition = new DockerComposition();
								composition.SelectedCryptos = new HashSet<string>();
								composition.SelectedCryptos.Add(btc);
								composition.SelectedCryptos.Add(ltc);
								composition.SelectedLN = lightning;
								composition.SelectedProxy = proxy;
								new Program().Run(composition, name, proxy == "nginx" ? productionLocation : testLocation);
							}
						}
					}
				}
			}
			else
			{
				var composition = DockerComposition.FromEnvironmentVariables();
				Console.WriteLine("Crypto: " + string.Join(", ", composition.SelectedCryptos.ToArray()));
				Console.WriteLine("Lightning: " + composition.SelectedLN);
				Console.WriteLine("ReverseProxy: " + composition.SelectedProxy);
				var generatedLocation = Path.GetFullPath(Path.Combine(root, "Generated"));

				var name = Environment.GetEnvironmentVariable("BTCPAYGEN_SUBNAME");
				name = string.IsNullOrEmpty(name) ? "generated" : name;
				new Program().Run(composition, name, generatedLocation);
			}
		}

		private void Run(DockerComposition composition, string name, string output)
		{
			var fragmentLocation = Environment.GetEnvironmentVariable("INSIDE_CONTAINER") == "1" ? "app" : "docker-compose-generator";
			fragmentLocation = FindRoot(fragmentLocation);
			fragmentLocation = Path.GetFullPath(Path.Combine(fragmentLocation, "docker-fragments"));

			var fragments = new List<string>();
			if(composition.SelectedProxy == "nginx")
			{
				fragments.Add("nginx");
			}
			else
			{
				fragments.Add("btcpayserver-noreverseproxy");
			}
			fragments.Add("btcpayserver");
			foreach(var crypto in CryptoDefinition.GetDefinitions())
			{
				if(!composition.SelectedCryptos.Contains(crypto.Crypto))
					continue;

				fragments.Add(crypto.CryptoFragment);
				if(composition.SelectedLN == "clightning" && crypto.CLightningFragment != null)
				{
					fragments.Add(crypto.CLightningFragment);
				}
                if(composition.SelectedLN == "lnd" && crypto.LNDFragment != null)
                {
                    fragments.Add(crypto.LNDFragment);
                }
            }

            foreach(var fragment in composition.AdditionalFragments)
            {
                fragments.Add(fragment.Trim());
            }

			var def = new DockerComposeDefinition(name, fragments);
			def.FragmentLocation = fragmentLocation;
			def.BuildOutputDirectory = output;
			def.Build();
		}

		private static string FindRoot(string rootDirectory)
		{
			string directory = Directory.GetCurrentDirectory();
			int i = 0;
			while(true)
			{
				if(i > 10)
					throw new DirectoryNotFoundException(rootDirectory);
				if(directory.EndsWith(rootDirectory))
					return directory;
				directory = Path.GetFullPath(Path.Combine(directory, ".."));
				i++;
			}
		}
	}
}
