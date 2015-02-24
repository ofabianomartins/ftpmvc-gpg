require 'ftpmvc/filter/base'
require 'gpgme'
require 'ftpd/stream'

module FTPMVC
  module Filter
    class Gpg < FTPMVC::Filter::Base
      def initialize(fs, chain, options={})
        super fs, chain
        @crypto = GPGME::Crypto.new(
          password: options[:passphrase], recipients: options[:recipients], always_trust: true)
        import_keys(options[:keys]) if options.include?(:keys)
      end

      def index(path)
        @chain.index(path).each do |node|
          if node.kind_of?(File) and not ::File.extname(node.name) == '.gpg'
            node.name = "#{node.name}.gpg"
          end
        end
      end

      def get(path)
        StringIO.new(@crypto.encrypt(original_data(path)).read)
      end

      def exists?(path)
        @chain.exists?(remove_extension(path))
      end

      def directory?(path)
        @chain.directory?(remove_extension(path))
      end

      def put(path, stream)
        buffer = ''
        while bytes = stream.read
          buffer << bytes
        end
        @chain.put(remove_extension(path), ::Ftpd::Stream.new(@crypto.decrypt(buffer), 'B'))
      end

      protected

      def original_data(path)
        GPGME::Data.from_io(@chain.get(remove_extension(path)))
      end

      def import_keys(keys)
        keys.each do |key|
          GPGME::Key.import(key.gsub(/^\s*/, ''))
        end
      end

      def remove_extension(path)
        path.gsub(/\.(gpg|pgp)$/, '')
      end
    end
  end
end
