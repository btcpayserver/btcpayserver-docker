using System;
using System.Collections.Generic;
using System.IO;
using YamlDotNet.Serialization;

namespace DockerGenerator
{
    class Program
    {
        static void Main(string[] args)
        {
			new Program().Run();
		}

		private void Run()
		{
			List<DockerComposeDefinition> defs = new List<DockerComposeDefinition>();
			defs.Add(new DockerComposeDefinition("btc",
						  new List<string> { "nginx", "btcpayserver", "bitcoin" }));
			defs.Add(new DockerComposeDefinition("btc-ltc",
						  new List<string> { "nginx", "btcpayserver", "bitcoin", "litecoin" }));

			var fragmentLocation = FindLocation("docker-fragments");
			var productionLocation = FindLocation("Production");
			foreach(var def in defs)
			{
				def.FragmentLocation = fragmentLocation;
				def.BuildOutputDirectory = productionLocation;
				def.Build();
			}

			var testLocation = FindLocation("Production-NoReverseProxy");
			foreach(var def in defs)
			{
				def.Fragments.Remove("nginx");
				def.Fragments.Add("btcpayserver-noreverseproxy");
				def.BuildOutputDirectory = testLocation;
				def.Build();
			}
		}

		private string FindLocation(string path)
		{
			while(true)
			{
				if(Directory.Exists(path))
					return path;
				path = Path.Combine("..", path);
			}
		}
	}
}
