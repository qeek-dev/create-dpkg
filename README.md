# create-dpkg
QPKG is the application package for QNAP turbo NAS. Developers can design add-ons or applications running on the NAS and have the applications and related data integrated on the same platform. Also, through the built-in App Center on QNAP Turbo NAS, users can easily install and manage those applications.

## QDK docker container
We build the QPKG with QDK docker container to simplify the buiding process. 

1. `build_qpkg.sh` is the main script for building QPKG.
2. `qdk-docker` contains the essential files for building QKD docker container.
3. `src` contains the asset, starting sctips, and your source code.

## File tree
```
.
├── build_qpkg.sh            // The main script
├── qdk-docker
│   ├── build-qdk-docker.sh  // The script for preparing QDK container
│   ├── Dockerfile
│   └── QDK                  // QDK from https://github.com/qnap-dev/QDK
└── src                      // source code folder
    ├── asset                // folder for asset
    │   ├── icons
    │   │   └── put-icon-here
    │   ├── package_routines
    │   └── qpkg.cfg
    └── init.d
        └── qctl.sh          // QPKG utility script
```

## Build QPKG
There are two modes of building QPKG:
1. Build QPKG only
2. Build QPKG and install to remote NAS
```
./build_qpkg.sh {CPU_ARCH} {QPKG_VERSION} [{REMOTE_HOST} {REMOTE_PASSWD}]
1.      CPU_ARCH: Target CPU architecture (x86_64, arm_64, arm-x41, arm-x31, ...)
2.  QPKG_VERSION: QPKG version of this build
3.   REMOTE_HOST: IP of NAS to install after building
4. REMOTE_PASSWD: Password of NAS to install after building

Example (1) build QPKG only
./build_qpkg.sh x86_64 1.0.0
Example (2) build QPKG and install to remote NAS
./build_qpkg.sh x86_64 1.0.0 {IP} {admin_password}
```

## Customize
You can highly customize your QPKG, including building process, package configuration, application icons, starting scripts, etc.

1. **Building Process**: We suggest to put the script for building your program on function `build_source()` in `build_qpkg.sh`. All the files in `${WORKSPACE_QPKG_ROOT}/shared` will be packed into QPKG, thus, pre-build executable is also acceptable.
2. **Package configuration**: You can config the QPKG by modifying `package_routines` and `qpkg.cfg`. Please refer [qnap-dev/QDK](https://github.com/qnap-dev/QDK).
3. **Application icons**: Put your application icons at `src/asset/icons`. Please refer [qnap-dev/QDK](https://github.com/qnap-dev/QDK) for the right file format.
4. **Starting scripts**: `src/init.d/qctl.sh` is the QPKG utility script. At least, the "start" and "stop" needs to be implemented. You can add the other functions, such as creating shared folder, checking system status, loging, etc.

## Also see
- [QNAP App Center](https://www.qnap.com/en/app_center/)
- [QNAP Developer Center](https://www.qnap.com/event/dev/en/p_about.php)
- [qnap-dev/QDK](https://github.com/qnap-dev/QDK)
- [Client Development Kit QDK (API & SDK)](https://www.qnap.com/event/dev/en/p_qdk.php)
