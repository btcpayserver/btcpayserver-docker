using System;
using System.Collections.Generic;
using System.Text;
using YamlDotNet.RepresentationModel;

namespace DockerFileBuildHelper
{
    public static class Extensions
    {
        public static YamlNode TryGet(this YamlNode node, string key)
        {
            try
            {
                return node[key];
            }
            catch (KeyNotFoundException) { return null; }
        }
    }
}
