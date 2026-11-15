using System;
using System.IO;
using System.Reflection;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Windows.Forms;

internal static class Launcher {
 [STAThread]
 private static void Main() {
  try {
   using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("App.ps1"))
   using (var reader = new StreamReader(stream))
   using (var runspace = RunspaceFactory.CreateRunspace()) {
    runspace.ApartmentState = ApartmentState.STA;
    runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
    runspace.Open();
    using (var shell = PowerShell.Create()) {
     shell.Runspace = runspace;
     shell.AddScript(reader.ReadToEnd());
     shell.Invoke();
     if (shell.HadErrors) {
      MessageBox.Show(shell.Streams.Error[0].ToString(), "Cumulative Screenshots: error");
     }
    }
   }
  } catch (Exception ex) { MessageBox.Show(ex.Message, "Cumulative Screenshots: error"); }
 }
}
