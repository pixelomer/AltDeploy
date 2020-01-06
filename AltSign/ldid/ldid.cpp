//
//  ldid.cpp
//  websign
//
//  ldid implentation file wrapper used to add our own logic without modifying ldid source.
//
//  Created by Riley Testut on 3/12/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

// Redefine ldid's main function to ldid_main to prevent duplicate main declarations.
#define main ldid_main

#include <ldid/ldid.cpp>

// Undefine our hacky main redefinition.
#undef main

namespace ldid
{
    // Based heavily on ldid::Sign executable locating logic.
    std::string ExecutablePath(std::string bundlePath)
    {
        auto folder = ldid::DiskFolder(bundlePath);
        
        std::string executable;
        
        bool mac(false);
        
        std::string info("Info.plist");
        if (!folder.Look(info) && folder.Look("Resources/" + info)) {
            mac = true;
            info = "Resources/" + info;
        }
        
        folder.Open(info, fun([&](std::streambuf &buffer, size_t length, const void *flag) {
            plist_d(buffer, length, fun([&](plist_t node) {
                executable = plist_s(plist_dict_get_item(node, "CFBundleExecutable"));
            }));
        }));
        
        if (!mac && folder.Look("MacOS/" + executable)) {
            executable = "MacOS/" + executable;
            mac = true;
        }
        
        return executable;
    }
    
    // Based heavily on ldid's -e argument logic.
    std::string Entitlements(std::string path)
    {
        struct stat info;
        _syscall(stat(path.c_str(), &info));
        
        if (S_ISDIR(info.st_mode))
        {
            path += "/" + ExecutablePath(path);
        }
        
        std::stringstream stringstream;
        
        Map mapping(path, false);
        FatHeader fat_header(mapping.data(), mapping.size());
        
        _foreach (mach_header, fat_header.GetMachHeaders())
        {
            struct linkedit_data_command *signature(NULL);
            
            _foreach (load_command, mach_header.GetLoadCommands())
            {
                uint32_t cmd(mach_header.Swap(load_command->cmd));
                if (cmd == LC_CODE_SIGNATURE)
                {
                    signature = reinterpret_cast<struct linkedit_data_command *>(load_command);
                }
            }
            
            if (signature != NULL)
            {
                uint32_t data = mach_header.Swap(signature->dataoff);
                
                uint8_t *top = reinterpret_cast<uint8_t *>(mach_header.GetBase());
                uint8_t *blob = top + data;
                struct SuperBlob *super = reinterpret_cast<struct SuperBlob *>(blob);
                
                for (size_t index(0); index != Swap(super->count); ++index)
                {
                    if (Swap(super->index[index].type) == CSSLOT_ENTITLEMENTS)
                    {
                        uint32_t begin = Swap(super->index[index].offset);
                        struct Blob *entitlements = reinterpret_cast<struct Blob *>(blob + begin);
                        
                        char *bytes = (char *)(entitlements + 1);
                        int size = Swap(entitlements->length) - sizeof(*entitlements);
                        
                        for (int i = 0; i < size; i++)
                        {
                            char byte = bytes[i];
                            stringstream << byte;
                        }
                        
                        if (size > 0)
                        {
                            auto entitlementsString = stringstream.str();
                            
                            // One valid mach_header is all we need to retrieve entitlements, so return to stop iterating over the next ones.
                            return entitlementsString;
                        }
                    }
                }
            }
        }
        
        // No entitlements found in any mach_header, so return empty string.
        return "";
    }
    
}
