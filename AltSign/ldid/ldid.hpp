//
//  ldid.hpp
//  websign
//
//  ldid header file wrapper used to add our own logic without modifying ldid source.
//
//  Created by Riley Testut on 3/12/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

#pragma once

#include <ldid/ldid.hpp>

namespace ldid
{
    std::string Entitlements(std::string path);
}
