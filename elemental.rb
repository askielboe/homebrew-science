class Elemental < Formula
  homepage "http://libelemental.org/"

  stable do
    url "https://github.com/elemental/Elemental/archive/0.85.tar.gz"
    sha256 "ccf2b8d3b92e99fb0f248b2c82222bef15a7644d7dc3a2826935216b0bd82d9d"
  end

  bottle do
    root_url "https://homebrew.bintray.com/bottles-science"
    sha256 "6ae6a4730ab89feb4b05072e809b07ed1c2d074f6efca5e9e96cb1c8aeb424ea" => :yosemite
    sha256 "8c5ec0fed0184bad047151cfbdec7a9c60c9d921cc9b4e041c7ed1122a6c8e34" => :mavericks
    sha256 "a57d7224e16c784815c5c670d73994d798b86821fb2e85cf5b18770ad74b1c57" => :mountain_lion
  end

  devel do
    url "https://github.com/elemental/Elemental/archive/0.86-rc1.tar.gz"
    sha256 "4f27c55828f27ce1685aaf65018cc149849692b7dfbd9352fc203fed1a96c924"
    version "0.86-rc1"
    depends_on :python => :recommended
    depends_on "metis"
  end

  head do
    url "https://github.com/elemental/Elemental.git"
    depends_on "metis"
  end

  option "without-check", "Skip build time tests (not recommended)"

  depends_on "cmake" => :build
  depends_on :mpi => [:cc, :cxx, :f90]

  depends_on "openblas"  => :optional
  depends_on "qt5"       => :optional
  depends_on "scalapack" => :optional

  needs :cxx11

  def install
    ENV.cxx11
    args = ["-DCMAKE_INSTALL_PREFIX=#{libexec}",  # Lots of junk ends up in bin.
            "-DCMAKE_FIND_FRAMEWORK=LAST",
            "-DCMAKE_VERBOSE_MAKEFILE=ON",
            "-DCMAKE_C_COMPILER=#{ENV["MPICC"]}",
            "-DCMAKE_CXX_COMPILER=#{ENV["MPICXX"]}",
            "-DCMAKE_Fortran_COMPILER=#{ENV["MPIFC"]}",
            "-Wno-dev"]

    # Python is disabled in stable because there's no way to
    # specify the destination of the Python files.
    if build.without? "python"
      args << "-DINSTALL_PYTHON_PACKAGE=OFF"
    else
      args << "-DPYTHON_SITE_PACKAGES=#{libexec}/lib/python2.7/site-packages"
    end

    if build.head?
      args << "-DCMAKE_BUILD_TYPE=Release"
      args << ("-DEL_HYBRID=" + ((ENV.compiler == :clang) ? "OFF" : "ON"))
    else
      args << "-DBUILD_KISSFFT=OFF"
      args << ("-DCMAKE_BUILD_TYPE=" + ((ENV.compiler == :clang) ? "Pure" : "Hybrid") + "Release")
    end

    math_libs = ""
    math_libs += "-L#{Formula["scalapack"].opt_lib} -lscalapack " if build.with? "scalapack"
    if build.with? "openblas"
      math_libs += "-L#{Formula["openblas"].opt_lib} -lopenblas"
    else
      math_libs += (OS.mac? ? "-framework Accelerate" : "-llapack -lblas -lm")
    end
    args << "-DMATH_LIBS=#{math_libs}"

    # METIS / ParMETIS.
    args << "-DBUILD_METIS=OFF"

    args += ["-DMANUAL_METIS=ON",
             "-DMETIS_ROOT=#{Formula["metis"].opt_prefix}",
             "-DMETIS_LIBS=-L#{Formula["metis"].opt_lib} -lmetis",
            ] if build.devel?

    # Building against our own ParMETIS seems borderline impossible
    # because of the mess in parmetislib.h.
    args += ["-DMETIS_INCLUDE_DIRS=#{Formula["metis"].opt_include}",
             "-DMETIS_LIBRARIES=-L#{Formula["metis"].opt_lib} -lmetis",
             "-DBUILD_PARMETIS=ON",
              # "-DBUILD_PARMETIS=OFF",
              # "-DPARMETIS_DIR=#{Formula["parmetis"].opt_libexec}",
              # "-DPARMETIS_INCLUDE_DIR=#{Formula["parmetis"].opt_include}",
              # "-DPARMETIS_LIB_DIR=#{Formula["parmetis"].opt_lib}",
            ] if build.head?

    # Bundle tests & examples together for check because examples directory
    # includes code that exercises Qt5 functionality (via spy plots)
    args += ["-DEL_TESTS=ON", "-DEL_EXAMPLES=ON"] if build.with? "check"
    args << "-DEL_USE_QT5=ON" if build.with? "qt5"

    mkdir "build" do
      system "cmake", "..", *args
      system "make"

      if build.with? "check"
        # If running in tmux with Qt5, get the error:
        # PasteBoard: Error creating pasteboard: com.apple.pasteboard.clipboard [-4960]
        # Seems to be a known issue with Qt running in tmux; see
        # https://github.com/ipython/ipython/issues/958.
        # To be safe, also mention other terminal multiplexers.
        opoo "Qt5 tests may return errors if run in tmux or GNU Screen" if build.with? "qt5"

        # Basic smoke test of build for now
        system "mpiexec", "-np", "2", "bin/tests/core/AxpyInterface"
        # Qt5 test; if enabled, spy plot of matrix will be made; otherwise,
        # test merely runs without producing spy plot
        system "mpiexec", "-np", "2", "bin/examples/matrices/Legendre"
      end

      system "make", "install"
      ln_sf libexec/"include", include
      ln_sf libexec/"lib", lib
    end
  end

  test do
    system libexec/"bin/examples/lapack_like/SVD", "--height", "300", "--width", "300"
  end
end
