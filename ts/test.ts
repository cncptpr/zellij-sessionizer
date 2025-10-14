import { execSync, spawn, spawnSync } from "child_process";

// function attachZellijSession(selectedPath: string, sessionName: string) {
//   if (!process.stdout.isTTY) {
//     console.error("Error: Must be run in an interactive terminal to attach to Zellij.");
//     return;
//   }

  // const child = spawn('zellij', ['attach', sessionName], {
  //   cwd: selectedPath,
  //   stdio: 'inherit', // Keeps the terminal the same
  // });

  // child.on('error', (error) => {
  //   console.error(`Failed to start zellij: ${error.message}`);
  // });

  // child.on('exit', (code) => {
  //   if (code !== 0) {
  //     console.error(`zellij failed with exit code ${code}`);
  //   }
  // });
// }

// attachZellijSession("~/dotfiles", "dotfiles");
  execSync("zellij");
