{ pkgs ? import (builtins.fetchTarball {
    # branches nixos-19.03
    url = "https://github.com/NixOS/nixpkgs-channels/archive/5271f8dddc0f2e54f55bd2fc1868c09ff72ac980.tar.gz";
    sha256 = "0w0x7whwb98lalaw25hxarmr924m1i49c1kacyypmnh2vjbkrjmi";
  }) {}
, show ? false
}:

with pkgs;

let

  python = python2Full.override {
    packageOverrides = self: super : {
      matplotlib = super.matplotlib.override {
        enableTk = show;
      };
    };
  };

  nfft = stdenv.mkDerivation rec {
    name = "nfft-3.5.1";
    src = fetchurl {
      url = "https://www-user.tu-chemnitz.de/~potts/nfft/download/${name}.tar.gz";
      sha256 = "1qzyfsbr10wqslgxdq9vifsaiszgm18hfx10pga75nf6831b55dv";
    };
    propagatedBuildInputs = [ fftw ];
    configureFlags = [
      "--enable-all"
      "--enable-openmp"
    ];
    enableParallelBuilding = true;
    doCheck = false;
  };

  astropy-helpers = with python.pkgs; buildPythonPackage rec {
    pname = "astropy-helpers";
    version = "2.0.10";
    src = fetchPypi {
      inherit pname version;
      sha256 = "0p5nbrz7b8df70x08hyzl365825vmb2x2p3vj1zhh1w65dp19jn5";
    };
    doCheck = false;
  };

  astropy = with python.pkgs; buildPythonPackage rec {
    pname = "astropy";
    version = "2.0.14";
    src = fetchPypi {
      inherit pname version;
      sha256 = "1dmf667nbhvpnkbgbh0dvim5ckwqx4j7d803njpdi909hq30g231";
    };
    nativeBuildInputs = [
      astropy-helpers
    ];
    postPatch = ''
      substituteInPlace setup.cfg --replace "auto_use = True" "auto_use = False"
    '';
    propagatedBuildInputs = [
      numpy
      (pytest_3.overridePythonAttrs(old: rec {
        pname = "pytest";
        version = "3.6.4";
        src = fetchPypi {
          inherit pname version;
          sha256 = "0h85kzdi5pfkz9v0z8xyrsj1rvnmyyjpng7cran28jmnc41w27il";
        };
        propagatedBuildInputs = [
          attrs
          funcsigs
          py
          setuptools
          six
          (pluggy.overridePythonAttrs(old: rec {
            pname = "pluggy";
            version = "0.7.1";
            src = fetchPypi {
              inherit pname version;
              sha256 = "95eb8364a4708392bae89035f45341871286a333f749c3141c20573d2b3876e1";
            };
            doCheck = false;
          }))
          more-itertools
          atomicwrites
        ];
        doCheck = false;
      }))
    ];
    doCheck = false;
  };

  pynfft = with python.pkgs; buildPythonPackage rec {
    pname = "pyNFFT";
    version = "1.3.2.post1";
    src = fetchurl {
      url = "https://github.com/pyNFFT/pyNFFT/archive/e2da0af374c6d7cc38992936ce4dda6e6c0ad7f1.tar.gz";
      sha256 = "1ifrq1i23ldri4i7hrs7ms0bnkbmwpm9p6m3kf3j28vhpqcpp2an";
    };
    nativeBuildInputs = [ cython ];
    buildInputs = [ nfft ];
    propagatedBuildInputs = [ numpy ];
    doCheck = false;
  };

  eht-imaging = with python.pkgs; buildPythonPackage {
    pname = "ehtim";
    version = "1.1.1";
    src = builtins.fetchurl {
      url = "https://github.com/achael/eht-imaging/archive/f8c4beb016d81b355ce236f6997cc058ae93733b.tar.gz";
      sha256 = "1f3nifl8bpimsw4v495c6j9ix1yla8gph2bvr51mxnrz91b86wym";
    };
    propagatedBuildInputs = [
      astropy
      ephem
      future
      h5py
      matplotlib
      networkx
      numpy
      scipy
      scikitimage
      ipython
      pynfft
    ];
    doCheck = false;
  };

  eht-imaging-env = python.buildEnv.override {
    extraLibs = with python.pkgs; [ eht-imaging ];
    ignoreCollisions = true;
  };

  eht-imaging-pipeline = stdenv.mkDerivation {
    name = "eht-imaging";
    src = builtins.fetchurl {
      url = "https://github.com/eventhorizontelescope/2019-D01-02/archive/587c5d6f3aa6d447d19c3542b7adcbaa1d62d13c.tar.gz";
      sha256 = "0ac61wg2500qa3lh78m311nj0a3pmryy407agyprdjil6blxkqw8";
    };
    installPhase = let show_updates = (if show then "True" else "False"); in ''
      mkdir -p $out/bin
      cp eht-imaging/eht-imaging_pipeline.py $out/bin
      sed -i '1s|^|#!${eht-imaging-env}/bin/python\n|' $out/bin/eht-imaging_pipeline.py
      substituteInPlace $out/bin/eht-imaging_pipeline.py \
        --replace "obs.add_scans()" "args.scanavg=True; obs.add_scans()" \
        --replace "imgr.make_image_I(show_updates=False)" "imgr.make_image_I(show_updates=${show_updates})"
      chmod u+x $out/bin/eht-imaging_pipeline.py
    '';
  };

  EHTC_FirstM87Results_Apr2019-png = stdenv.mkDerivation {
    name = "EHTC_FirstM87Results_Apr2019.png";
    src = builtins.fetchurl {
      url = "https://de.cyverse.org/anon-files/iplant/home/shared/commons_repo/curated/EHTC_FirstM87Results_Apr2019/EHTC_FirstM87Results_Apr2019_uvfits.tgz";
      sha256 = "0qyl3q7h1c0r0gclxikmcivbbld39g9lwhngbmi75xqc9kz7fvzk";
    };
    buildPhase = ''
      eht-imaging_pipeline.py -i uvfits/SR1_M87_2017_101_lo_hops_netcal_StokesI.uvfits -o final.fits
    '';
    installPhase = ''
      convert final.fits $out
    '';
    buildInputs = [
      eht-imaging-pipeline
      imagemagick
    ];
    shellHook = ''
      tar xzvf $src
      eht-imaging_pipeline.py -i EHTC_FirstM87Results_Apr2019/uvfits/SR1_M87_2017_101_lo_hops_netcal_StokesI.uvfits -o final.fits
      convert final.fits final.png
    '';
  };

in EHTC_FirstM87Results_Apr2019-png
