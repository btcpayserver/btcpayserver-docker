using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace DockerFileBuildHelper
{
    public class StringBuilderEx
    {
        StringBuilder _Builder = new StringBuilder();
        public StringBuilderEx()
        {

        }

        public int Indent { get; set; }

        public void Append(string str)
        {
            _Builder.Append(GetIndents());
            _Builder.Append(str);
        }

        private string GetIndents()
        {
            return new String(Enumerable.Range(0, Indent).Select(_ => '\t').ToArray());
        }

        public void AppendLine(string str)
        {
            _Builder.Append(GetIndents());
            _Builder.AppendLine(str);
        }

        public override string ToString()
        {
            return _Builder.ToString();
        }

        internal void AppendLine()
        {
            _Builder.AppendLine();
        }
    }
}
