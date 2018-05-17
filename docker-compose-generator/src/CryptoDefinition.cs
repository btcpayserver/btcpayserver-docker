using System;
using System.Collections.Generic;
using System.Text;

namespace DockerGenerator
{
    public class CryptoDefinition
    {
		public string Crypto
		{
			get;
			private set;
		}
		public string CryptoFragment
		{
			get;
			private set;
		}
		public string CLightningFragment
		{
			get;
			private set;
		}

		public static CryptoDefinition[] GetDefinitions()
		{
			return new[]
			{
				new CryptoDefinition()
				{
					Crypto = "ltc",
					CryptoFragment = "litecoin",
					CLightningFragment = "litecoin-clightning",
				},
				new CryptoDefinition()
				{
					Crypto = "btc",
					CryptoFragment = "bitcoin",
					CLightningFragment = "bitcoin-clightning",
				},
			};
		}
    }
}
