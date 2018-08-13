﻿using System;
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
        public string LNDFragment
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
                    LNDFragment = "litecoin-lnd"
                },
                new CryptoDefinition()
                {
                    Crypto = "btc",
                    CryptoFragment = "bitcoin",
                    CLightningFragment = "bitcoin-clightning",
                    LNDFragment = "bitcoin-lnd"
                },
                new CryptoDefinition()
                {
                    Crypto = "btg",
                    CryptoFragment = "bgold",
                    LNDFragment = "bgold-lnd"
                },
                new CryptoDefinition()
                {
                    Crypto = "ftc",
                    CryptoFragment = "feathercoin"
                },
                new CryptoDefinition()
                {
                    Crypto = "grs",
                    CryptoFragment = "groestlcoin"
                },
                new CryptoDefinition()
                {
                    Crypto = "via",
                    CryptoFragment = "viacoin"
                }
            };
        }
    }
}
