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
			var btc = new DockerComposeDefinition("btc",
						  new string[] { "nginx", "btcpayserver", "bitcoin" });
			defs.Add(btc);
			defs.Add(new DockerComposeDefinition("btc-ltc",
						  new string[] { "nginx", "btcpayserver", "bitcoin", "litecoin" }));

			var fragmentLocation = FindLocation("docker-fragments");
			var productionLocation = FindLocation("Production");
			foreach(var def in defs)
			{
				def.FragmentLocation = fragmentLocation;
				def.BuildOutputDirectory = productionLocation;
				def.Build();
			}
			File.Copy(btc.GetFilePath(), Path.Combine(new FileInfo(btc.GetFilePath()).Directory.FullName, "docker-compose.yml"), true);
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
