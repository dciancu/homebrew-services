class GotenbergDocker < Formula
  desc "Homebrew service wrapper to run Gotenberg inside a Docker container with custom configurations"
  homepage "https://gotenberg.dev"
  # Pointing to /dev/null tells Homebrew to read a local empty file
  url "file:///dev/null"
  # This is the exact SHA-256 hash of an empty file
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  version "1.1.0"

  # Marked as optional so Homebrew doesn't force-install its own docker CLI package
  depends_on "docker" => :optional

  def install
    # 1. Create the default configuration file in the build path
    (buildpath/"gotenberg-docker.conf").write <<~EOS
      # Gotenberg Docker service configuration

      # The container version/tag of Gotenberg to run
      # See https://hub.docker.com/r/gotenberg/gotenberg/tags
      GOTENBERG_VERSION="latest"

      # Add space-separated domains that should resolve to the host machine (host-gateway)
      # Example:
      # GOTENBERG_DOMAINS="my-local-site.test api.internal.local"
      GOTENBERG_DOMAINS=""
    EOS

    # 2. Install config safely. Homebrew will not overwrite modifications on upgrade.
    etc.install "gotenberg-docker.conf"

    # 3. Create the wrapper script
    (bin/"gotenberg-docker").write <<~EOS
      #!/bin/bash

      # Load configuration file
      CONFIG_FILE="#{etc}/gotenberg-docker.conf"
      GOTENBERG_DOMAINS=""
      GOTENBERG_VERSION="latest"
      if [ -f "\$CONFIG_FILE" ]; then
        source "\$CONFIG_FILE"
      fi

      # Fallback to "latest" if variable is empty or cleared
      if [ -z "\$GOTENBERG_VERSION" ]; then
        GOTENBERG_VERSION="latest"
      fi

      DOCKER_BIN=\$(which docker)
      if [ -z "\$DOCKER_BIN" ]; then
        for path in "/opt/homebrew/bin/docker" "/usr/local/bin/docker" "/usr/bin/docker"; do
          if [ -x "\$path" ]; then
            DOCKER_BIN="\$path"
            break
          fi
        done
      fi

      if [ -z "\$DOCKER_BIN" ]; then
        echo "Error: Docker binary not found. Please ensure Docker is installed and running." >&2
        exit 1
      fi

      # Build the --add-host arguments from config
      ADD_HOST_FLAGS=()
      for domain in \$GOTENBERG_DOMAINS; do
        ADD_HOST_FLAGS+=("--add-host" "\$domain:host-gateway")
      done

      # Clean up any existing container using this name
      "\$DOCKER_BIN" rm -f gotenberg-service 2>/dev/null

      # Pull new image version
      "$DOCKER_BIN" pull gotenberg/gotenberg:"\$GOTENBERG_VERSION"

      # Execute the container with configured version and host resolution arguments
      exec "\$DOCKER_BIN" run --rm \\
        "\${ADD_HOST_FLAGS[@]}" \\
        --name gotenberg-service \\
        -p 127.0.0.1:3000:3000 \\
        gotenberg/gotenberg:"\$GOTENBERG_VERSION"
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
      Ensure Docker is running on your machine before starting the service:
        brew services start gotenberg-docker
      The service is available at:
        http://127.0.0.1:3000
      Service health endpoint:
        http://127.0.0.1:3000/health

      A default configuration file has been installed to:
        #{etc}/gotenberg-docker.conf

      You can edit this file to configure the container version tag and host resolution mapping.
      Remember to restart the service after modifying the file:
        brew services restart gotenberg-docker
    EOS
  end
end
