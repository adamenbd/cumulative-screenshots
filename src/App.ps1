Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CaptureNative {
 [DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();

 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
[void][CaptureNative]::SetProcessDPIAware()
Add-Type -ReferencedAssemblies System.Drawing,System.Windows.Forms -TypeDefinition @'
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
public class CaptureList : CheckedListBox {
 bool allowChange;
 public void SetCaptureChecked(int index,bool value) {
  bool previous=allowChange; allowChange=true;
  try { SetItemChecked(index,value); } finally { allowChange=previous; }
 }
 protected override void OnItemCheck(ItemCheckEventArgs e) {
  if(!allowChange) e.NewValue=e.CurrentValue;
  base.OnItemCheck(e);
 }
 protected override void WndProc(ref Message m) {
  bool previous=allowChange;
  if(m.Msg==0x201 || m.Msg==0x202 || m.Msg==0x203) {
   int x=(short)(m.LParam.ToInt64() & 65535);
   int y=(short)((m.LParam.ToInt64() >> 16) & 65535);
   using(var g=CreateGraphics()) { allowChange=x>=0 && x<(int)(24*g.DpiX/96) && IndexFromPoint(x,y)>=0; }
  } else if(m.Msg==0x100 && m.WParam.ToInt32()==32) allowChange=true;
  try { base.WndProc(ref m); } finally { allowChange=previous; }
 }
}
public class CaptureNotice : Form {
 [DllImport("user32.dll")] static extern bool SetWindowDisplayAffinity(IntPtr window,uint affinity);
 protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); SetWindowDisplayAffinity(Handle,0x11); }
 protected override bool ShowWithoutActivation { get { return true; } }
 protected override CreateParams CreateParams { get { var p=base.CreateParams; p.ExStyle |= 0x08000000 | 0x80; return p; } }
 public CaptureNotice() {
  FormBorderStyle=FormBorderStyle.None; ShowInTaskbar=false; TopMost=true;
  BackColor=Color.FromArgb(20,110,65); ForeColor=Color.White;
  Size=new Size(420,100); StartPosition=FormStartPosition.Manual;
 }
}
public static class CursorCapture {
 [StructLayout(LayoutKind.Sequential)] struct POINT { public int X,Y; }
 [StructLayout(LayoutKind.Sequential)] struct RECT { public int L,T,R,B; }
 [StructLayout(LayoutKind.Sequential)] struct CURSORINFO { public int Size,Flags; public IntPtr Cursor; public POINT Pos; }
 [StructLayout(LayoutKind.Sequential)] struct ICONINFO { public bool Icon; public int X,Y; public IntPtr Mask,Color; }
 delegate IntPtr HookProc(int n,IntPtr w,IntPtr l);
 static HookProc callback=Hook;
 static IntPtr hook,icon;
 static POINT pos;
 static RECT rect;
 static DateTime captured;
 [DllImport("user32.dll")] static extern bool GetCursorInfo(ref CURSORINFO c);
 [DllImport("user32.dll")] static extern IntPtr CopyIcon(IntPtr h);
 [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr h);
 [DllImport("user32.dll")] static extern bool GetIconInfo(IntPtr h,out ICONINFO info);
 [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr h);
 [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h,int a,out RECT r,int size);
 [DllImport("user32.dll")] static extern bool DrawIconEx(IntPtr dc,int x,int y,IntPtr icon,int w,int h,int step,IntPtr brush,int flags);
 [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id,HookProc cb,IntPtr module,uint thread);
 [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
 [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h,int n,IntPtr w,IntPtr l);
 [DllImport("kernel32.dll",CharSet=CharSet.Auto)] static extern IntPtr GetModuleHandle(string name);
 static RECT extended;
 public static void Remember() {
  if(icon!=IntPtr.Zero) { DestroyIcon(icon); icon=IntPtr.Zero; }
  var c=new CURSORINFO(); c.Size=Marshal.SizeOf(c);
  if(GetCursorInfo(ref c) && (c.Flags & 1)!=0) { icon=CopyIcon(c.Cursor); pos=c.Pos; }
  var window=GetForegroundWindow(); GetWindowRect(window,out rect);
  if(DwmGetWindowAttribute(window,9,out extended,Marshal.SizeOf(typeof(RECT)))!=0) extended=rect;
  captured=DateTime.UtcNow;
 }
 static IntPtr Hook(int n,IntPtr w,IntPtr l) {
  if(n>=0 && (w.ToInt32()==0x100 || w.ToInt32()==0x104) && Marshal.ReadInt32(l)==0x2C) Remember();
  return CallNextHookEx(hook,n,w,l);
 }
 public static void Start() {
  hook=SetWindowsHookEx(13,callback,GetModuleHandle(null),0);
  if(hook==IntPtr.Zero) throw new System.ComponentModel.Win32Exception();
 }
 public static void Stop() { if(hook!=IntPtr.Zero) UnhookWindowsHookEx(hook); if(icon!=IntPtr.Zero) { DestroyIcon(icon); icon=IntPtr.Zero; } }
 public static void Stamp(Bitmap bitmap) {
  if(icon==IntPtr.Zero || (DateTime.UtcNow-captured).TotalSeconds>2) return;
  RECT bounds=rect;
  if(bitmap.Width==extended.R-extended.L && bitmap.Height==extended.B-extended.T) bounds=extended;
  else if(bitmap.Width!=rect.R-rect.L || bitmap.Height!=rect.B-rect.T) return;
  ICONINFO info;
  if(!GetIconInfo(icon,out info)) return;
  try {
   using(var g=Graphics.FromImage(bitmap)) {
    var dc=g.GetHdc();
    try { DrawIconEx(dc,pos.X-bounds.L-info.X,pos.Y-bounds.T-info.Y,icon,0,0,0,IntPtr.Zero,3); }
    finally { g.ReleaseHdc(dc); }
   }
  } finally { if(info.Mask!=IntPtr.Zero) DeleteObject(info.Mask); if(info.Color!=IntPtr.Zero) DeleteObject(info.Color); }
 }
}
'@
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:shots = New-Object System.Collections.ArrayList
$script:sequence = [CaptureNative]::GetClipboardSequenceNumber()

$script:totalPixels = 0L

$form = New-Object Windows.Forms.Form
$form.Text = 'Cumulative Screenshots'
$form.Size = New-Object Drawing.Size(960,700)
$form.MinimumSize = New-Object Drawing.Size(760,500)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI',10)
$tray = New-Object Windows.Forms.NotifyIcon
$tray.Icon = [Drawing.SystemIcons]::Application
$tray.Text = 'Cumulative Screenshots'
$tray.Visible = $true
$tray.Add_Click({ $form.Show(); $form.WindowState = 'Normal'; $form.Activate() })
$notice = New-Object CaptureNotice
$noticeLabel = New-Object Windows.Forms.Label
$noticeLabel.Dock = 'Fill'
$noticeLabel.TextAlign = 'MiddleCenter'
$noticeLabel.Font = New-Object Drawing.Font('Segoe UI',15,[Drawing.FontStyle]::Bold)
$notice.Controls.Add($noticeLabel)
$noticeTimer = New-Object Windows.Forms.Timer
$noticeTimer.Interval = 2200
$noticeTimer.Add_Tick({ $notice.Hide(); $noticeTimer.Stop() })
$noticeLabel.Add_Click({ $notice.Hide(); $form.WindowState = 'Normal'; $form.Activate() })

$bar = New-Object Windows.Forms.FlowLayoutPanel
$bar.Dock = 'Top'
$bar.Height = 88
$bar.Padding = New-Object Windows.Forms.Padding(10)
$bar.WrapContents = $true
$form.Controls.Add($bar)
function Button($text, $action) {
 $b = New-Object Windows.Forms.Button
 $b.Text = $text
 $b.AutoSize = $true
 $b.Height = 32
 $b.Add_Click($action)
 $bar.Controls.Add($b)
}
$list = New-Object CaptureList
$list.CheckOnClick = $true
$list.Dock = 'Left'
$list.Width = 210
$form.Controls.Add($list)
$preview = New-Object Windows.Forms.PictureBox
$preview.Dock = 'Fill'
$preview.SizeMode = 'Zoom'
$preview.BackColor = [Drawing.Color]::FromArgb(35,39,46)
$form.Controls.Add($preview)
$preview.BringToFront()
$bar.BringToFront()
$status = New-Object Windows.Forms.Label
$status.Dock = 'Bottom'
$status.Height = 55
$status.Padding = New-Object Windows.Forms.Padding(10)
$form.Controls.Add($status)

function Refresh-Shots {
 $script:refreshing = $true
 $selected = $list.SelectedIndex
 $list.Items.Clear()
 for ($i=0; $i -lt $script:shots.Count; $i++) {
  $s = $script:shots[$i]
  [void]$list.Items.Add(('{0}. {1}  ({2} x {3})' -f ($i+1),$s.Time,$s.Image.Width,$s.Image.Height))
  $list.SetCaptureChecked($i,[bool]$s.Included)
 }
 if ($script:shots.Count -gt 0) { $list.SelectedIndex = [Math]::Max(0,[Math]::Min($selected,$script:shots.Count-1)) }
 else { $preview.Image = $null }
 $script:refreshing = $false
 $status.Text = "$($script:shots.Count) screenshots. Check the ones to paste, then press Ctrl+V in your destination app."
 if ($script:syncTimer) { $script:syncTimer.Stop(); $script:syncTimer.Start() }
}
$list.Add_SelectedIndexChanged({
 if ($list.SelectedIndex -ge 0) { $preview.Image = $script:shots[$list.SelectedIndex].Image }
})
function Sync-Selected {
 $chosen = @($script:shots | Where-Object { $_.Included })
 if ($chosen.Count -eq 0) {
  if ($null -ne $script:ownedSequence -and [CaptureNative]::GetClipboardSequenceNumber() -eq $script:ownedSequence) {
   [Windows.Forms.Clipboard]::Clear()
   $script:sequence = [CaptureNative]::GetClipboardSequenceNumber()
  }
  $script:ownedSequence = $null
  $status.Text = 'No screenshots checked for pasting.'
  return
 }
 try {
  $folder = Join-Path ([IO.Path]::GetTempPath()) ('CumulativeScreenshots-' + [Guid]::NewGuid().ToString('N'))
  [void][IO.Directory]::CreateDirectory($folder)
  $files = New-Object System.Collections.Specialized.StringCollection
  $fragment = '<!--StartFragment-->'
  for ($i=0; $i -lt $chosen.Count; $i++) {
   $path = Join-Path $folder ('Screenshot-{0:D3}.png' -f ($i+1))
   $chosen[$i].Image.Save($path,[Drawing.Imaging.ImageFormat]::Png)
   [void]$files.Add($path)
   $uri = ([Uri]$path).AbsoluteUri
   $fragment += '<p><img src="' + $uri + '"></p>'
  }
  $fragment += '<!--EndFragment-->'
  $headerTemplate = "Version:0.9`r`nStartHTML:{0:D10}`r`nEndHTML:{1:D10}`r`nStartFragment:{2:D10}`r`nEndFragment:{3:D10}`r`n"
  $dummy = $headerTemplate -f 0,0,0,0
  $prefix = '<html><body>'
  $suffix = '</body></html>'
  $utf8 = [Text.Encoding]::UTF8
  $startHtml = $utf8.GetByteCount($dummy)
  $startFragment = $startHtml + $utf8.GetByteCount($prefix + '<!--StartFragment-->')
  $endFragment = $startHtml + $utf8.GetByteCount($prefix + $fragment.Replace('<!--EndFragment-->',''))
  $endHtml = $startHtml + $utf8.GetByteCount($prefix + $fragment + $suffix)
  $html = ($headerTemplate -f $startHtml,$endHtml,$startFragment,$endFragment) + $prefix + $fragment + $suffix
  $data = New-Object Windows.Forms.DataObject
  $data.SetFileDropList($files)
  $data.SetData([Windows.Forms.DataFormats]::Html,$html)
  [Windows.Forms.Clipboard]::SetDataObject($data,$true)
  $script:sequence = [CaptureNative]::GetClipboardSequenceNumber()
  $script:ownedSequence = $script:sequence
  $status.Text = "$($chosen.Count) of $($script:shots.Count) screenshots ready for Ctrl+V as separate PNG files."
 } catch { $status.Text = 'Clipboard busy. Retrying...'; $script:syncTimer.Start() }
}
$script:syncTimer = New-Object Windows.Forms.Timer
$script:syncTimer.Interval = 80
$script:syncTimer.Add_Tick({ $script:syncTimer.Stop(); Sync-Selected })
$list.Add_ItemCheck({
 if ($script:refreshing) { return }
 $script:shots[$_.Index].Included = ($_.NewValue -eq [Windows.Forms.CheckState]::Checked)
 $script:syncTimer.Stop(); $script:syncTimer.Start()
})
Button 'Delete previewed screenshot' {
 $i = $list.SelectedIndex
 if ($i -ge 0) {
  $preview.Image = $null
  $s = $script:shots[$i]
  $script:totalPixels -= [long]$s.Image.Width * $s.Image.Height
  $s.Image.Dispose()
  $script:shots.RemoveAt($i)
  Refresh-Shots
 }
}
Button 'Clear list' {
 if ($script:shots.Count -eq 0) { return }
 if ([Windows.Forms.MessageBox]::Show('Remove all screenshots from the list?','Clear list','YesNo') -ne 'Yes') { return }
 $preview.Image = $null
 foreach ($s in $script:shots) { $s.Image.Dispose() }
 $script:shots.Clear()
 $script:totalPixels = 0L
 Refresh-Shots
}
Button 'Export all screenshots' {
 if ($script:shots.Count -eq 0) { return }
 $dialog = New-Object Windows.Forms.SaveFileDialog
 $dialog.AutoUpgradeEnabled = $true
 $dialog.Title = 'Save PNG screenshots (additional files use -002, -003...)'
 $dialog.Filter = 'PNG image (*.png)|*.png'
 $dialog.DefaultExt = 'png'
 $dialog.AddExtension = $true
 $dialog.FileName = 'screenshot-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.png'
 if ($dialog.ShowDialog($form) -eq 'OK') {
  try {
   $folder = [IO.Path]::GetDirectoryName($dialog.FileName)
   $stem = [IO.Path]::GetFileNameWithoutExtension($dialog.FileName)
   $paths = @($dialog.FileName)
   for ($i=1; $i -lt $script:shots.Count; $i++) {
    $paths += Join-Path $folder ('{0}-{1:D3}.png' -f $stem,($i+1))
   }
   $existing = @($paths | Select-Object -Skip 1 | Where-Object { [IO.File]::Exists($_) })
   if ($existing.Count -gt 0 -and [Windows.Forms.MessageBox]::Show("There are already $($existing.Count) numbered files. Overwrite them?",'Save PNG files','YesNo') -ne 'Yes') { return }
   for ($i=0; $i -lt $script:shots.Count; $i++) {
    $script:shots[$i].Image.Save($paths[$i],[Drawing.Imaging.ImageFormat]::Png)
   }
   $status.Text = "Saved $($script:shots.Count) screenshots to $folder"
  } catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Unable to save') }
 }
 $dialog.Dispose()
}


$timer = New-Object Windows.Forms.Timer
$timer.Interval = 250
$timer.Add_Tick({
 $current = [CaptureNative]::GetClipboardSequenceNumber()
 if ($current -eq $script:sequence) { return }
 try {
  if ([Windows.Forms.Clipboard]::ContainsImage()) {
   $img = [Windows.Forms.Clipboard]::GetImage()
   if ($null -ne $img) {
    try {
     $pixels = [long]$img.Width * $img.Height
     if ($script:totalPixels + $pixels -gt 100000000) {
      $status.Text = 'Memory limit reached. Export and delete screenshots to continue.'
     } else {
      $copy = New-Object Drawing.Bitmap($img)
      [CursorCapture]::Stamp($copy)
      [void]$script:shots.Add([pscustomobject]@{ Image=$copy; Time=(Get-Date -Format 'HH:mm:ss'); Included=$true })
      $script:totalPixels += $pixels
      Refresh-Shots
      $list.SelectedIndex = $script:shots.Count-1
      $tray.BalloonTipTitle = 'Screenshot saved'
      $tray.BalloonTipText = "$($script:shots.Count) screenshots collected. Click the tray icon to review them."
      $tray.ShowBalloonTip(2500)
      $noticeTimer.Stop()
      $area = [Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position).WorkingArea
      $notice.Location = New-Object Drawing.Point(($area.Right-$notice.Width-20),($area.Bottom-$notice.Height-20))
      $noticeLabel.Text = "SCREENSHOT CAPTURED  #$($script:shots.Count)`nAdded to your list"
      $notice.Show()
      $noticeTimer.Start()
     }
    } finally { $img.Dispose() }
   }
  }
  $script:sequence = $current
 } catch { } # Clipboard temporarily busy: retry on the next tick.
})
$form.Add_FormClosed({
 $script:syncTimer.Stop(); $script:syncTimer.Dispose()
 # Leave normal single-image clipboard behavior after the app closes.
 if ($null -ne $script:ownedSequence -and [CaptureNative]::GetClipboardSequenceNumber() -eq $script:ownedSequence) {
  try {
   if ($script:shots.Count -gt 0) { [Windows.Forms.Clipboard]::SetImage($script:shots[$script:shots.Count-1].Image) }
   else { [Windows.Forms.Clipboard]::Clear() }
  } catch { }
 }
 $timer.Stop(); $timer.Dispose()
 $tray.Visible = $false
 $tray.Dispose()
 $noticeTimer.Stop(); $noticeTimer.Dispose(); $notice.Dispose()
 [CursorCapture]::Stop()
 $preview.Image = $null
 foreach ($s in $script:shots) { $s.Image.Dispose() }
})
Refresh-Shots
# Listen for future captures without taking one at startup.
[CursorCapture]::Start()
$timer.Start()
[Windows.Forms.Application]::Run($form)
