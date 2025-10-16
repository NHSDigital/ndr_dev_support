require 'capistrano/recipes/deploy/strategy/copy'

# Do not include macOS extended attributes in capistrano tar files
#
# Without this, the system default tar (bsdtar) creates AppleDouble files with a
# ._ prefix, and the linux default tar (gnutar) generates many warnings such as:
# tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.provenance'
#
# This fix works because we compress files only locally, for capistrano deployments.
# If we were compressing files remotely too, we would instead need to selectively
# redefine behaviour for local tar usage vs remote usage, e.g. by adding a
# :copy_local_tar_options variable, similar to :copy_local_tar
module CopyMacosTarSupport
  private

  def compress(directory, file)
    if compression.compress_command[0] == 'tar' && local_tar_is_macos_bsdtar?
      return macos_bsdtar_compress(directory, file)
    end

    super
  end

  def local_tar_is_macos_bsdtar?
    RUBY_PLATFORM =~ /darwin/ && system('tar --version | grep -q ^bsdtar')
  end

  def macos_bsdtar_compress(directory, file)
    compression.compress_command + [file, '--no-xattr', '--no-mac-metadata', directory]
  end
end

Capistrano::Deploy::Strategy::Copy.prepend(CopyMacosTarSupport)
