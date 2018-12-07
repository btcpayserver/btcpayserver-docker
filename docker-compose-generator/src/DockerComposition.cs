using System;
using System.Linq;
using System.Collections.Generic;
using System.Text;

namespace DockerGenerator
{
	public class DockerComposition
	{
		private const string DefaultDatabase = "postgres";
		
		public HashSet<string> SelectedCryptos
		{
			get;
			set;
		}
		public string SelectedProxy
		{
			get;
			set;
		}

		public string SelectedDatabase
		{
			get;
			set;
		}
		public string SelectedLN
		{
			get;
			set;
		}
		public string[] AdditionalFragments
		{
			get;
			set;
		} = new string[0];


		public static DockerComposition FromEnvironmentVariables()
		{
			DockerComposition composition = new DockerComposition();
			composition.SelectedCryptos = new HashSet<string>();
			for (int i = 1; i < 10; i++)
			{
				var selectedCrypto = Environment.GetEnvironmentVariable("BTCPAYGEN_CRYPTO" + i);
				if (string.IsNullOrEmpty(selectedCrypto))
					continue;
				composition.SelectedCryptos.Add(selectedCrypto.ToLowerInvariant());
			}

			composition.SelectedDatabase =
				GetEnvVarOrDefault("BTCPAYGEN_DATABASE", DefaultDatabase).ToLowerInvariant();

			composition.SelectedProxy = GetEnvVarOrDefault("BTCPAYGEN_REVERSEPROXY", string.Empty).ToLowerInvariant();

			composition.SelectedLN = GetEnvVarOrDefault("BTCPAYGEN_LIGHTNING", string.Empty).ToLowerInvariant();

			composition.AdditionalFragments = GetEnvVarOrDefault("BTCPAYGEN_ADDITIONAL_FRAGMENTS", string.Empty)
				.ToLowerInvariant()
				.Split(new char[] {';', ','})
				.Where(t => !string.IsNullOrWhiteSpace(t))
				.Select(t => t.EndsWith(".yml") ? t.Substring(0, t.Length - ".yml".Length) : t)
				.ToArray();
			return composition;
		}

		private static string GetEnvVarOrDefault(string key, string defaultValue)
		{
			var result = Environment.GetEnvironmentVariable(key);
			return string.IsNullOrEmpty(result) ? defaultValue : result;
		}
	}
}
