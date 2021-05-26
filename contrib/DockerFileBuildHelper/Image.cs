using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace DockerFileBuildHelper
{
    public class Image
    {
        public string User { get; private set; }
        public string Name { get; private set; }
        public string Tag { get; private set; }

        public string DockerHubLink
        {
            get
            {
                return User == string.Empty ?
                    $"https://hub.docker.com/_/{Name}" :
                    $"https://hub.docker.com/r/{User}/{Name}";
            }
        }

        public string Source { get; set; }

        public static Image Parse(string str)
        {
            //${BTCPAY_IMAGE: -btcpayserver / btcpayserver:1.0.3.21}
            var variableMatch = Regex.Match(str, @"\$\{[^-]+-([^\}]+)\}");
            if (variableMatch.Success)
            {
                str = variableMatch.Groups[1].Value;
            }
            Image img = new Image();
            var match = Regex.Match(str, "([^/]*/)?([^:]+):?(.*)");
            if (!match.Success)
                throw new FormatException();
            img.User = match.Groups[1].Length == 0 ? string.Empty : match.Groups[1].Value.Substring(0, match.Groups[1].Value.Length - 1);
            img.Name = match.Groups[2].Value;
            img.Tag = match.Groups[3].Value;
            if (img.Tag.Contains('@'))
            {
                img.Tag = img.Tag.Split('@')[0];
            }
            if (img.Tag == string.Empty)
                img.Tag = "latest";
            return img;
        }
        public override string ToString()
        {
            return ToString(true);
        }
        public string ToString(bool includeTag)
        {
            StringBuilder builder = new StringBuilder();
            if (!String.IsNullOrWhiteSpace(User))
                builder.Append($"{User}/");
            builder.Append($"{Name}");
            if (includeTag)
            {
                if (!String.IsNullOrWhiteSpace(Tag))
                    builder.Append($":{Tag}");
            }
            return builder.ToString();
        }
    }
}
