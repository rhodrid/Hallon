# coding: utf-8
module Hallon
  # Images are JPEG images that can be linked to and saved.
  #
  # @see http://developer.spotify.com/en/libspotify/docs/group__image.html
  class Image
    extend Linkable

    from_link(:image) do |link, session|
      Spotify::image_create_from_link(session.pointer, link)
    end

    to_link(:image)

    # Image triggers `:load` when loaded
    include Hallon::Observable

    # Create a new instance of an Image.
    #
    # @param [String, Link, FFI::Pointer] link
    # @param [Hallon::Session] session
    def initialize(link, session = Session.instance)
      @callback = proc { trigger(:load) }
      @pointer  = Spotify::Pointer.new from_link(link, session), :image
      Spotify::image_add_load_callback(@pointer, @callback, nil)

      # TODO: remove load_callback when @pointer is released
      # TODO: this makes libspotify segfault, figure out why
      # on(:load) { Spotify::image_remove_load_callback(@pointer, @callback, nil) }
    end

    # True if the image has been loaded.
    #
    # @return [Boolean]
    def loaded?
      Spotify::image_is_loaded(@pointer)
    end

    # Retrieve the current error status.
    #
    # @return [Symbol] error
    def status
      Spotify::image_error(@pointer)
    end

    # Retrieve image format.
    #
    # @return [Symbol] `:jpeg` or `:unknown`
    def format
      Spotify::image_format(@pointer)
    end

    # Retrieve image ID as a hexadecimal string.
    #
    # @return [String]
    def id
      Spotify::image_image_id(@pointer).read_string(20).unpack('H*')[0]
    end

    # Raw image data as a binary encoded string.
    #
    # @return [String]
    def data
      FFI::MemoryPointer.new(:size_t) do |size|
        data = Spotify::image_data(@pointer, size)
        return data.read_bytes(size.read_size_t)
      end
    end
  end
end
