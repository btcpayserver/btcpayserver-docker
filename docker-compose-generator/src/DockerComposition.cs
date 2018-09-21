﻿using System;
using System.Linq;
using System.Collections.Generic;
using System.Text;

namespace DockerGenerator
{
	public class DockerComposition
	{
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
			for(int i = 1; i < 10; i++)
			{
				var selectedCrypto = Environment.GetEnvironmentVariable("BTCPAYGEN_CRYPTO" + i);
				if(string.IsNullOrEmpty(selectedCrypto))
					continue;
				composition.SelectedCryptos.Add(selectedCrypto.ToLowerInvariant());
			}
			composition.SelectedProxy = (Environment.GetEnvironmentVariable("BTCPAYGEN_REVERSEPROXY") ?? "").ToLowerInvariant();
			composition.SelectedLN = (Environment.GetEnvironmentVariable("BTCPAYGEN_LIGHTNING") ?? "").ToLowerInvariant();
			composition.AdditionalFragments = (Environment.GetEnvironmentVariable("BTCPAYGEN_ADDITIONAL_FRAGMENTS") ?? "").ToLowerInvariant().Split(';').Where(t => !string.IsNullOrWhiteSpace(t)).ToArray();
			return composition;
		}
	}
}
