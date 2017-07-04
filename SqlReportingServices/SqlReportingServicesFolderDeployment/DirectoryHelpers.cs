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

        public static Dictionary<string, string> GetFolderStructure(string root,string remoteRoot)
        {
            root = Path.GetFullPath(root);
            if (root.LastIndexOf('\\') == root.Length - 1)
            {
                root = root.Substring(0, root.Length - 1);
            }
            if (remoteRoot.LastIndexOf('/') == remoteRoot.Length - 1)
            {
                remoteRoot = remoteRoot.Substring(0, remoteRoot.Length - 1);
            }
            Console.WriteLine(root);
            var rootName = Path.GetDirectoryName(root);
            Dictionary<string, string> ret = new Dictionary<string, string>();
            foreach (var di in new DirectoryInfo(root).GetDirectories("*", SearchOption.AllDirectories))
            {
                var relPath = di.Parent.FullName.Replace(root, "").Replace("\\", "/");
                if (di.Parent.Name.Equals(rootName,StringComparison.OrdinalIgnoreCase) && Path.GetFullPath(di.Parent.FullName).Split('\\').Length == root.Split('\\').Length)
                {
                    relPath = "/";
                }                
                var remPath = remoteRoot + relPath + "/" + di.Name;
                if (!ret.ContainsKey(remPath))
                {
                    ret.Add(remPath, di.Name);
                }
            }
            return ret;
        }

        public static string ExtractRemotePath(string path, string localRoot, string remoteRoot)
        {
            //if it is the local root, return /
            if (path.Replace("\\", "").Equals(localRoot.Replace("\\", ""), StringComparison.OrdinalIgnoreCase))
            {
                return remoteRoot;
            }

            string newPath = path.Replace(localRoot, "").Replace("\\","/");
            if(newPath.IndexOf("/") == 0)
            {
                newPath = newPath.Substring(0);
            }
            if (remoteRoot.LastIndexOf('/') == remoteRoot.Length - 1)
                return remoteRoot + newPath;
            else
                return remoteRoot + "/" + newPath;
        }
    }
}
