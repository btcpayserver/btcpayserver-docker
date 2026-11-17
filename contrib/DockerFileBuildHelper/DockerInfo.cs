namespace DockerFileBuildHelper
{
    public class DockerInfo
    {
        public string DockerFilePath { get; set; }
        public string DockerFilePathARM32v7 { get; set; }
        public string DockerFilePathARM64v8 { get; set; }
        public string DockerHubLink { get; set; }
        public string GitLink { get; set; }
        public string GitRef { get; set; }
        public bool SupportedByUs { get; set; }
        public bool Deprecated { get; set; }
        public Image Image { get; internal set; }
        public string RawLink { get; set; }
        public string GetGithubLinkOf(string path)
        {
            return RawLink ?? $"https://raw.githubusercontent.com/{GitLink.Substring("https://github.com/".Length)}{(GitRef is null ? string.Empty : ("/" + GitRef))}/{path}";
        }
    }
}
