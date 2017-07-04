using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Tobania.SqlReportingFolderDeployment
{
    public class DirectoryHelpers
    {
        public DirectoryHelpers() { }

        public static Dictionary<string, string> GetFolderStructure(string root, string remoteRoot)
        {
            root = Path.GetFullPath(root);
            if (root.LastIndexOf('\\') != root.Length - 1)
            {
                root += "\\";
            }
            if (remoteRoot.LastIndexOf('/') == remoteRoot.Length - 1)
            {
                remoteRoot = remoteRoot.Substring(0, remoteRoot.Length - 1);
            }
            var rootName = Path.GetDirectoryName(root);
            Dictionary<string, string> ret = new Dictionary<string, string>();
            foreach (var di in new DirectoryInfo(root).GetDirectories("*", SearchOption.AllDirectories))
            {

                var relPath = GetRelativePath(root, di.Parent.FullName);
                if (relPath.IndexOf("..") == 0)
                {
                    relPath = "/";
                }
                var remPath = remoteRoot;
                if (relPath.IndexOf('/') != 0)
                {
                    remPath += "/";
                }
                remPath += relPath + "/" + di.Name;
                remPath = CleanRemotePath(remPath);
                ret[remPath] = di.Name;
            }
            return ret;
        }

        public static string GetRelativePath(string root, string child)
        {

            Uri rootUri = new Uri(root, UriKind.Absolute);
            Uri childUri = new Uri(child, UriKind.Absolute);
            var outUri = Uri.UnescapeDataString(rootUri.MakeRelativeUri(childUri).ToString());
            if (outUri.IndexOf("..") == 0)
            {
                outUri = "/";
            }

            return outUri;
        }

        public static string ExtractRemotePath(string path, string localRoot, string remoteRoot)
        {
            var newPath = GetRelativePath(localRoot, path);
            if (newPath.IndexOf("/") == 0)
            {
                newPath = newPath.Substring(0);
            }
            if (remoteRoot.LastIndexOf('/') == remoteRoot.Length - 1)
                return CleanRemotePath(remoteRoot + newPath);
            else
                return CleanRemotePath(remoteRoot + "/" + newPath);
        }

        public static string CleanRemotePath(string path)
        {
            var t = path.Replace("\\", "/").Replace("//", "/");
            if(t.LastIndexOf("/") == t.Length - 1)
            {
                t = t.Substring(0, t.Length - 1);
            }
            return t;
        }
    }
}
