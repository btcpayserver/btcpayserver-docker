using System;
using System.Collections.Generic;
using System.Text;

namespace DockerFileBuildHelper
{
    public class DockerFile
    {
        public string DockerFileName { get; private set; }
        public string DockerDirectoryPath { get; private set; }
        public string DockerFullPath
        {
            get
            {
                if (DockerDirectoryPath == ".")
                    return $"{DockerFileName}";
                else
                    return $"{DockerDirectoryPath}/{DockerFileName}";
            }
        }

        public static DockerFile Parse(string str)
        {
            var file = new DockerFile();
            var lastPart = str.LastIndexOf('/');
            file.DockerFileName = str.Substring(lastPart + 1);
            if (lastPart == -1)
            {
                file.DockerDirectoryPath = ".";
            }
            else
            {
                file.DockerDirectoryPath = str.Substring(0, lastPart);
            }
            return file;
        }
    }
}
