#!/bin/sh
printf '%b\n' '
<openbox_pipe_menu>

  <item label="Web Browser" name.action="Execute" command.action="waterfox" icon="waterfox" />
  <item label="Terminal" name.action="Execute" command.action="foot" icon="utilities-terminal" />
  <item label="File Manager" name.action="Execute" command.action="caja" icon="system-file-manager" />
  <item label="Tweaks" name.action="Execute" command.action="labwc-tweaks" icon="configure" />

  <separator />'

labwc-menu-generator -I -b -n -t foot

printf '%b\n' '
  <separator />

  <menu id="Preferences" label="Preferences" icon="applications-engineering">
    <item label="Edit rc.xml" name.action="Execute" command.action="foot -e nano ~/.config/labwc/rc.xml" icon="text-x-generic" />
    <item label="Edit autostart" name.action="Execute" command.action="foot -e nano ~/.config/labwc/autostart" icon="text-x-generic" />
  </menu>

  <menu id="Exit" label="Exit" icon="application-exit">
    <item label="Reconfigure" name.action="Reconfigure" icon="labwc" />
    <item label="Logout" name.action="Exit" icon="application-exit" />
  </menu>

</openbox_pipe_menu>'
