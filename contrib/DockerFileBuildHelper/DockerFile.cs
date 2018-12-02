using System;
using System.Collections.Generic;
using System.Text;

namespace DockerFileBuildHelper
{
    public class DockerFile
    {
        public string DockerFileName { get; private set; }
        public string DockerFilePath { get; private set; }

        public static DockerFile Parse(string str)
        {
            var file = new DockerFile();
            var lastPart = str.LastIndexOf('/');
            file.DockerFileName = str.Substring(lastPart + 1);
            if (lastPart == -1)
            {
                file.DockerFilePath = ".";
            }
            else
            {
                file.DockerFilePath = str.Substring(0, lastPart);
            }
            return file;
        }
    }
}
