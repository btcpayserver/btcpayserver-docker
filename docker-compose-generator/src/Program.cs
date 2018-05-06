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
			new Program().Run();
		}

		private void Run()
		{
			var fragmentLocation = FindLocation("docker-fragments");
			var productionLocation = FindLocation("Production");
			var testLocation = FindLocation("Production-NoReverseProxy");

			HashSet<string> processed = new HashSet<string>();
			foreach(var permutation in ItemCombinations(new[] { "btc", "ltc", "clightning" }.ToList()))
			{
				if(permutation.Count == 1 && permutation.First() == "clightning")
					continue;
				permutation.Sort();
				if(permutation.Remove("clightning"))
					permutation.Add("clightning"); // ensure clightning at the end
				string id = string.Join('-', permutation);
				if(!processed.Add(id))
					continue;

				var fragments = new List<string>();
				fragments.Add("nginx");
				fragments.Add("btcpayserver");

				if(permutation.Contains("ltc"))
				{
					fragments.Add("litecoin");
					if(permutation.Contains("clightning"))
						fragments.Add("litecoin-clightning");
				}
				if(permutation.Contains("btc"))
				{
					fragments.Add("bitcoin");
					if(permutation.Contains("clightning"))
						fragments.Add("bitcoin-clightning");
				}

				var def = new DockerComposeDefinition(id, fragments);
				def.FragmentLocation = fragmentLocation;
				def.BuildOutputDirectory = productionLocation;
				def.Build();


				def.Fragments.Remove("nginx");
				def.Fragments.Add("btcpayserver-noreverseproxy");
				def.BuildOutputDirectory = testLocation;
				def.Build();
			}
		}

		/// <summary>
		/// Method to create lists containing possible combinations of an input list of items. This is 
		/// basically copied from code by user "jaolho" on this thread:
		/// http://stackoverflow.com/questions/7802822/all-possible-combinations-of-a-list-of-values
		/// </summary>
		/// <typeparam name="T">type of the items on the input list</typeparam>
		/// <param name="inputList">list of items</param>
		/// <param name="minimumItems">minimum number of items wanted in the generated combinations, 
		///                            if zero the empty combination is included,
		///                            default is one</param>
		/// <param name="maximumItems">maximum number of items wanted in the generated combinations,
		///                            default is no maximum limit</param>
		/// <returns>list of lists for possible combinations of the input items</returns>
		public static List<List<T>> ItemCombinations<T>(List<T> inputList, int minimumItems = 1,
														int maximumItems = int.MaxValue)
		{
			int nonEmptyCombinations = (int)Math.Pow(2, inputList.Count) - 1;
			List<List<T>> listOfLists = new List<List<T>>(nonEmptyCombinations + 1);

			if(minimumItems == 0)  // Optimize default case
				listOfLists.Add(new List<T>());

			for(int i = 1; i <= nonEmptyCombinations; i++)
			{
				List<T> thisCombination = new List<T>(inputList.Count);
				for(int j = 0; j < inputList.Count; j++)
				{
					if((i >> j & 1) == 1)
						thisCombination.Add(inputList[j]);
				}

				if(thisCombination.Count >= minimumItems && thisCombination.Count <= maximumItems)
					listOfLists.Add(thisCombination);
			}

			return listOfLists;
		}

		private string FindLocation(string path)
		{
			string directory = path;
			int i = 0;
			while(true)
			{
				if(i > 10)
					throw new DirectoryNotFoundException(directory);
				if(Directory.Exists(path))
					return path;
				path = Path.Combine("..", path);
				i++;
			}
		}
	}
}
