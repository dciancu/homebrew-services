class GotenbergDocker < Formula
  desc "Homebrew service wrapper to run Gotenberg inside a Docker container"
  homepage "https://gotenberg.dev"
  version "1.0.1"
  # Pointing to /dev/null tells Homebrew to read a local empty file
  url "file:///dev/null"
  # This is the exact SHA-256 hash of an empty file
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  depends_on "docker" => :optional

  def install
    # Write a wrapper script that locates Docker and starts the container
    (bin/"gotenberg-docker").write <<~EOS
      #!/bin/bash

      # Attempt to locate the docker binary in standard installation paths
      DOCKER_BIN=$(which docker)
      if [ -z "$DOCKER_BIN" ]; then
        for path in "/opt/homebrew/bin/docker" "/usr/local/bin/docker" "/usr/bin/docker"; do
          if [ -x "$path" ]; then
            DOCKER_BIN="$path"
            break
          fi
        done
      fi

      if [ -z "$DOCKER_BIN" ]; then
        echo "Error: Docker binary not found. Please ensure Docker is installed and running." >&2
        exit 1
      fi

      # Force clean any existing container using this name to avoid conflicts
      "$DOCKER_BIN" rm -f gotenberg-service 2>/dev/null

      # Pull new image version
      "$DOCKER_BIN" pull gotenberg/gotenberg:8

      # Run Gotenberg in the foreground so the service manager can monitor the process.
      # By using --rm, the container is deleted automatically when the service stops.
      exec "$DOCKER_BIN" run --rm --name gotenberg-service -p 127.0.0.1:3000:3000 gotenberg/gotenberg:8
    EOS

    chmod 0755, bin/"gotenberg-docker"
  end

  service do
    run [opt_bin/"gotenberg-docker"]
    keep_alive true
    run_type :immediate
    environment_variables PATH: "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  end

  def caveats
    <<~EOS
      This service wraps Gotenberg in a Docker container.
      Ensure Docker Desktop (or Colima / Podman) is running on your machine before starting the service:
        brew services start gotenberg-docker
      The service is available at: http://127.0.0.1:3000
      Service health endpoint: http://127.0.0.1:3000/health
    EOS
  end
end
