{
  description = "Wrapper for Sebastiaan76/waybar_wireplumber_audio_changer";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      audio_changer = pkgs.writeScript "audio_changer.py"
        ''
          #!/usr/bin/env python 
          import subprocess

          # function to parse output of command "wpctl status" and return a dictionary of sinks with their id and name.
          def parse_wpctl_status():
              # Execute the wpctl status command and store the output in a variable.
              output = str(subprocess.check_output("wpctl status", shell=True, encoding='utf-8'))

              # remove the ascii tree characters and return a list of lines
              lines = output.replace("├", "").replace("─", "").replace("│", "").replace("└", "").splitlines()

              # get the index of the Sinks line as a starting point
              sinks_index = None
              for index, line in enumerate(lines):
                  if "Sinks:" in line:
                      sinks_index = index
                      break

              # start by getting the lines after "Sinks:" and before the next blank line and store them in a list
              sinks = []
              for line in lines[sinks_index +1:]:
                  if not line.strip():
                      break
                  sinks.append(line.strip())

              # remove the "[vol:" from the end of the sink name
              for index, sink in enumerate(sinks):
                  sinks[index] = sink.split("[vol:")[0].strip()
    
              # strip the * from the default sink and instead append "- Default" to the end. Looks neater in the anyrun list this way.
              for index, sink in enumerate(sinks):
                  if sink.startswith("*"):
                      sinks[index] = sink.strip().replace("*", "").strip() + " - Default"

              # make the dictionary in this format {'sink_id': <int>, 'sink_name': <str>}
              sinks_dict = [{"sink_id": int(sink.split(".")[0]), "sink_name": sink.split(".")[1].strip()} for sink in sinks]

              return sinks_dict

          #if there's only 2 outputs then action just switch and return the next id, if there's more, show anyrun for selection
          def get_selected_sink_id(sinks):
              if len(sinks) == 2:
                  for index, item in enumerate(sinks):
                      if not item['sink_name'].endswith(" - Default"):
                          return item['sink_id']
              else: 
                  # get the list of sinks ready to put into anyrun - highlight the current default sink
                  output = '''
                  for items in sinks:        
                      if items['sink_name'].endswith(" - Default"):
                          output += f"→ {items['sink_name']}\n"
                      else:
                          output += f"{items['sink_name']}\n"

                  # Call anyrun and show the list. take the selected sink name and set it as the default sink
                  anyrun_command = f"echo '{output}' | anyrun --show-results-immediately true --plugins ${pkgs.anyrun}/lib/libstdin.so"
                  anyrun_process = subprocess.run(anyrun_command, shell=True, encoding='utf-8', stdout=subprocess.PIPE, stderr=subprocess.PIPE)

                  if anyrun_process.returncode != 0:
                      print("User cancelled the operation.")
                      exit(0)

                  selected_sink_name = anyrun_process.stdout.strip()
                  selected_sink = next(sink for sink in sinks if sink['sink_name'] == selected_sink_name)
                  return selected_sink['sink_id']

          selected_sink_id = get_selected_sink_id(parse_wpctl_status())
          subprocess.run(f"wpctl set-default {selected_sink_id}", shell=True)
        '';
    };
}
