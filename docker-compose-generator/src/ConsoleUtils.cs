using System;
using System.Collections.Generic;
using System.Text;

namespace DockerGenerator
{
	public static class ConsoleUtils
	{
		public static void WriteLine(string message, ConsoleColor color)
		{
			var old = Console.ForegroundColor;
			Console.ForegroundColor = color;
			Console.WriteLine(message);
			Console.ForegroundColor = old;
		}
	}
}
