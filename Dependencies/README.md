# Dependencies

**Q:** Why are these precompiled?
**A:** I tried to add them as a dependency in the code. I tried for hours. I couldn't. These precompiled libraries come from brew.sh since I just wasn't able to compile them myself.

**Q:** What's "Individual" and what's "dependencies.deb"?
**A:** When I individually linked the libraries, Xcode always linked the dynamic libraries as well, which I didn't want. So I packed all of the objects inside of one archive and linked that instead, which worked
