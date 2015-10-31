require 'ffi'

require "ffi_mpg123/version"

module MPG123
  extend FFI::Library
  # ffi_lib 'mpg123.so'
  ffi_lib '/usr/local/lib/libmpg123.so'

  enum :params, [:verbose, 0,
                 :resync_limit, 14]

  enum :status, [:err, -1,
                 :ok, 0]
  enum :version, []
  enum :mode, []
  enum :flags, []
  enum :vbr, []

  class String < FFI::Struct
    layout :p, :pointer,
      :size, :size_t,
      :fill, :size_t
  end

  class Text < FFI::Struct
    layout :lang, [:char, 3],
      :id, [:char, 4],
      :description, MPG123::String,
      :text, MPG123::String
  end

  class FrameInfo < FFI::Struct
    layout :version, :int, #enum mpg123_version
      :layer, :int,
      :rate, :long,
      :mode, :int, #enum mpg123_mode
      :mode_ext, :int,
      :framesize, :int,
      :flags, :int, #enum mpg123_flags
      :emphasis, :int,
      :bitrate, :int,
      :abr_rate, :int,
      :vbr, :int #enum mpg123_vbr
  end

  class ID3v1 < FFI::Struct
    layout :tag, [:char, 3],
      :title, [:char, 30],
      :artist, [:char, 30],
      :album, [:char, 30],
      :year, [:char, 4],
      :comment, [:char, 30],
      :genre, :uchar
  end

  class ID3v2 < FFI::Struct
    layout :version, :uchar,
      :title, MPG123::String.ptr,
      :artist, MPG123::String.ptr,
      :album, MPG123::String.ptr,
      :year, MPG123::String.ptr,
      :genre, MPG123::String.ptr,
      :comment, MPG123::String.ptr,
      :comment_list, MPG123::Text.ptr,
      :comments, :size_t,
      :text, MPG123::Text.ptr,
      :texts, :size_t,
      :extra, MPG123::Text.ptr,
      :extras, :size_t
  end

  attach_function :mpg123_init,       [], :status
  attach_function :mpg123_exit,       [], :void
  attach_function :mpg123_new,        [:string, :pointer], :pointer
  attach_function :mpg123_delete,     [:pointer], :void
  attach_function :mpg123_open,       [:pointer, :string], :status
  attach_function :mpg123_close,      [:pointer], :status
  attach_function :mpg123_scan,       [:pointer], :status
  attach_function :mpg123_info,       [:pointer, :pointer], :status
  attach_function :mpg123_length,     [:pointer], :off_t
  attach_function :mpg123_meta_check, [:pointer], :status
  attach_function :mpg123_id3,        [:pointer, :pointer, :pointer], :status
  attach_function :mpg123_param,      [:pointer, :params, :long, :double], :status

  class Handle
    attr_reader :pointer

    def initialize(pointer, opts = {})
      @pointer = pointer
      process_options(opts)
    end

    def open(filename)
      puts "Opening ERROR" unless MPG123.mpg123_open(@pointer, filename) == :ok
      self
    end

    def close
      puts "Closing ERROR" unless MPG123.mpg123_close(@pointer) == :ok
      self
    end

    def scan
      MPG123.mpg123_scan(@pointer)
      self
    end

    def info
      frame_info = FrameInfo.new(FFI::MemoryPointer.new(:int, MPG123::FrameInfo.size, false))
      MPG123.mpg123_info(@pointer, frame_info)
      yield frame_info if block_given?
      self
    end

    def length
      MPG123.mpg123_length(@pointer)
    end

    private

    def process_options(opts)
      default_params = {
        :verbose => [:verbose, 0, 0],
        :resync_limit => [:resync_limit, -1, 0]
      }

      # mpg123_param(m, MPG123_RESYNC_LIMIT, -1, 0)

      default_params.each_value do |param|
        MPG123.mpg123_param(@pointer, *param)
      end
    end
  end

  def self.init
    puts "Initialization ERROR" unless mpg123_init == :ok
  end

  def self.exit
    mpg123_exit
  end

  def self.setup
    self.init
    yield self
    self.exit
  end

  def self.create(opts = {})
    Handle.new mpg123_new(nil, nil)
  end

  def self.delete(handle)
    mpg123_delete(handle.pointer)
  end

  def self.open(filename)
    handle = MPG123.create
    yield handle.open(filename) if block_given?
    handle.close
    MPG123.delete(handle)
  end

  def self.id3_dump filename
    MPG123.open(filename) do |handle|
      # v1 = FrameInfo.new(FFI::MemoryPointer.new(:int, MPG123::ID3v1.size, false))
      # v2 = FrameInfo.new(FFI::MemoryPointer.new(:int, MPG123::ID3v2.size, false))
      # status = mpg123_meta_check(handle.pointer)
      # if status & :id3 && mpg123_id3(handle.pointer, v1, v2)
      # end

      handle.scan.info do |frame_info|
        puts frame_info[:layer]
        puts frame_info[:bitrate]
        puts frame_info[:abr_rate]
        puts frame_info[:vbr]
        puts frame_info[:framesize]
      end
      puts handle.length
    end
  end
end
