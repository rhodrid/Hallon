# coding: utf-8
module Hallon
  # Users are the entities that interact with the Spotify service.
  #
  # Methods are available for retrieving metadata and relationship
  # status between users.
  #
  # @see http://developer.spotify.com/en/libspotify/docs/group__user.html
  class User < Base
    extend Linkable

    # A Post is created upon sending tracks (with an optional message) to a user.
    #
    # @see http://developer.spotify.com/en/libspotify/docs/group__inbox.html
    class Post < Base
      include Observable

      # @param [Spotify::Pointer<inbox>]
      def initialize(username, message, tracks, &block)
        @callback = proc { trigger(:load) }

        FFI::MemoryPointer.new(:pointer, tracks.length) do |ary|
          ary.write_array_of_pointer tracks.map(&:pointer)
          @pointer = Spotify.inbox_post_tracks!(session.pointer, username, ary, tracks.length, message, @callback, nil)
        end
      end

      # @see Error.explain
      # @return [Symbol] error status of inbox post
      def status
        Spotify.inbox_error(pointer)
      end
    end

    from_link :profile do |link|
      Spotify.link_as_user!(link)
    end

    to_link :from_user

    # Construct a new instance of User.
    #
    # @example from a canonical username
    #   Hallon::User.new("burgestrand")
    #
    # @example from a spotify URI
    #   Hallon::User.new("spotify:user:burgestrand")
    #
    # @note You can also instantiate User with a canonical username
    # @param [String, Link, Spotify::Pointer] link
    def initialize(link)
      @pointer = to_pointer(link, :user) do
        if link.is_a?(String) and link !~ /\Aspotify:user:/
          to_pointer("spotify:user:#{link}", :user)
        end
      end
    end

    # @return [Boolean] true if the user is loaded.
    def loaded?
      Spotify.user_is_loaded(pointer)
    end

    # @return [String] canonical name of the User.
    def name
      Spotify.user_canonical_name(pointer)
    end

    # @note Unless {#loaded?} is true, this will return the same thing as {#name}.
    # @return [String] display name of the User.
    def display_name
      Spotify.user_display_name(pointer)
    end

    # @note Returns nil unless {User#loaded?}
    # @return [Playlist, nil] starred playlist of the User.
    def starred
      playlist = Spotify.session_starred_for_user_create!(session.pointer, name)
      Playlist.from(playlist)
    end

    # @note Returns nil unless {#loaded?}
    # @return [PlaylistContainer, nil] published playlists of the User.
    def published
      container = Spotify.session_publishedcontainer_for_user_create!(session.pointer, name)
      PlaylistContainer.from(container)
    end

    # Send tracks to this users’ inbox, with an optional message.
    #
    # @overload post(message, tracks)
    #   @param [#to_s] message
    #   @param [Array<Track>] tracks
    #
    # @overload post(tracks)
    #   @param [Array<Track>] tracks
    #
    # @return [Post, nil]
    def post(message = nil, tracks)
      message &&= message.encode('UTF-8')
      post = Post.new(name, message, tracks)
      post unless post.pointer.null?
    end
  end
end
