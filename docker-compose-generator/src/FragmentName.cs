using System;
using System.Collections.Generic;
using System.Text;

namespace DockerGenerator
{
	public class FragmentName
	{
		public FragmentName(string fragmentName)
		{
			if (fragmentName == null)
				throw new ArgumentNullException(nameof(fragmentName));
			Name = fragmentName.Trim().ToLowerInvariant();
			if (Name.EndsWith(".yml", StringComparison.OrdinalIgnoreCase))
				Name = Name.Substring(0, Name.Length - 4);
		}
		public string Name { get; }

		public override bool Equals(object obj)
		{
			FragmentName item = obj as FragmentName;
			if (item == null)
				return false;
			return Name.Equals(item.Name);
		}
		public static bool operator ==(FragmentName a, FragmentName b)
		{
			if (System.Object.ReferenceEquals(a, b))
				return true;
			if (((object)a == null) || ((object)b == null))
				return false;
			return a.Name == b.Name;
		}

		public static bool operator !=(FragmentName a, FragmentName b)
		{
			return !(a == b);
		}

		public override int GetHashCode()
		{
			return Name.GetHashCode();
		}
		public override string ToString()
		{
			return Name;
		}
	}
}
