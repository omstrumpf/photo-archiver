# Photo Archiver
Archives photos from google-photos

# Usage
1. Set up a google API account, note your client ID and client secret
2. Authorize this app with Google: `photo_archiver authorize`
3. Generate a config file `photo_archiver gen-config`
4. Archive! `photo_archiver archive`
   * You probably want to automate this to run daily or something. See the included Dockerfile which takes care of this.
5. Optionally, schedule `photo_archiver sync-db` to occasionally sanity check that the db is in sync with the filesystem.

# Building
1. `opam switch create .`
2. dune build
3. docker build