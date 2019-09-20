using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using YamlDotNet.RepresentationModel;

namespace DockerGenerator
{
	// Replace built time variable ( $<variable_name>? ) in the docker generator
	class BuildTimeVariableVisitor : YamlVisitorBase
	{
		class Context
		{
			public List<YamlScalarNode> ToRemove = new List<YamlScalarNode>();
		}
		Stack<Context> _Contexts = new Stack<Context>();
		Context CurrentContext
		{
			get
			{
				return _Contexts.TryPeek(out var ctx) ? ctx : null;
			}
		}

		protected override void VisitChildren(YamlSequenceNode sequence)
		{
			_Contexts.Push(new Context());
			base.VisitChildren(sequence);
			var ctx = _Contexts.Pop();
			foreach (var child in ctx.ToRemove)
			{
				sequence.Children.Remove(child);
			}
		}
		public override void Visit(YamlScalarNode scalar)
		{
			bool removeNode = false;
			scalar.Value = Regex.Replace(scalar.Value, "\\$<(.*?)>\\?", (match) =>
			{
				var replacedBy = Environment.GetEnvironmentVariable(match.Groups[1].Value);
				if (string.IsNullOrEmpty(replacedBy))
				{
					removeNode = true;
				}
				return replacedBy;
			});
			if (removeNode)
				CurrentContext?.ToRemove.Add(scalar);
			base.Visit(scalar);
		}
	}
}
