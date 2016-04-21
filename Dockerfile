# Base image https://hub.docker.com/_/perl/
FROM perl:latest

# install cpanm
RUN curl -L http://cpanmin.us | perl - App::cpanminus

# install dependencies
RUN cpanm Cache::Memcached
RUN cpanm Catalyst::Action::RenderView
RUN cpanm Catalyst::Controller::REST
RUN cpanm Catalyst::Devel
RUN cpanm Catalyst::Model::DBIC::Schema
RUN cpanm Catalyst::Plugin::ConfigLoader
RUN cpanm Catalyst::Plugin::PageCache
RUN cpanm Catalyst::Plugin::Static::Simple
RUN cpanm Catalyst::Plugin::Unicode
RUN cpanm Catalyst::Runtime
RUN cpanm Catalyst::ScriptRunner
RUN cpanm Catalyst::View::Email
RUN cpanm Catalyst::View::TT
RUN cpanm Config::General
RUN cpanm Data::Printer
RUN cpanm Data::UUID
RUN cpanm DateTime::Format::MySQL
RUN cpanm DBD::mysql
RUN cpanm Email::Valid

# install libgb, required for GD.pm
RUN apt-get update && apt-get install -y libgd2-xpm-dev && apt-get clean
RUN cpanm GD

RUN cpanm HTML::FormHandler::Moose
RUN cpanm HTML::Scrubber
RUN cpanm Log::Log4perl::Catalyst
RUN cpanm --force MediaWiki::Bot
RUN cpanm Search::QueryParser
RUN cpanm --verbose Template::Plugin::Number::Format
RUN cpanm Term::Size::Any
RUN cpanm XML::Feed
RUN cpanm DBIx::Class::Result::ColumnData
RUN cpanm SQL::Translator
RUN cpanm MooseX::ClassAttribute

# create a symbolic link for shared static files
RUN ln -s /src/PfamBase/root/static /src/RfamWeb/root/shared

# setup environment variables
ENV PERL5LIB=/src/RfamWeb\
:/src/Rfam/Schemata\
:/src/PfamBase/lib\
:/src/PfamLib\
:/src/PfamSchemata

ENV RFAMWEB_CONFIG=/src/RfamWeb/config/rfamweb.conf
ENV DBIC_TRACE=1

EXPOSE 3000

ENTRYPOINT ["/src/RfamWeb/script/rfamweb_server.pl", "-p", "3000", "--debug", "--restart"]
