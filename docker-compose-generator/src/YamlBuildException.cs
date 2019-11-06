using System;
using System.Collections.Generic;
using System.Text;

namespace DockerGenerator
{
	public class YamlBuildException : Exception
	{
		public YamlBuildException(string message): base(message)
		{

		}
	}
}
