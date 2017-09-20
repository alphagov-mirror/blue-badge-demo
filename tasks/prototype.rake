# This file contains tasks for grabbing everything
# from the 'pde-design-sprint1' repository that's
# necessary to render the prototype.

# Run `rake prototype` to do the generation.
# If you don't have a copy of the prototype repository,
# run `git submodule update --init` first.

ROOT = File.join '.', 'pde-design-sprint1'
ASSETS_DIR = File.join ROOT, 'app', 'assets' 
VIEW_DIR = File.join ROOT, 'app', 'views'
GOVUK_MODULES_DIR = File.join ROOT, 'node_modules'
GOVUK_ASSETS_DIR = File.join GOVUK_MODULES_DIR, 'govuk_template_jinja', 'assets'
TRANSPILER = File.join '.', 'meta-template'
TRANSPILER_MODULES_DIR = File.join TRANSPILER, 'node_modules'

desc 'Grab all of the files required by the web prototype'
task :prototype => [:'prototype:stylesheets', :'prototype:templates', :'prototype:javascripts', :'prototype:images']

namespace :prototype do
  desc 'Install the dependencies to grab from'
  directory GOVUK_MODULES_DIR do
    cd ROOT do
      sh 'npm install'
    end
  end

  desc 'Install the transpiler'
  directory TRANSPILER_MODULES_DIR do
    cd TRANSPILER do
      sh 'npm install'
    end
  end

  desc 'Generate all the liquid templates by converting the nunjucks sources'
  task :templates => FileList[
    './views/v2-b/start-page.liquid',
    './views/v2-b/signin.liquid',
    './views/v2-b/applicant-details.liquid',
    './views/v2-b/response-approved.liquid',
    './views/v2-b/response-referred.liquid',
    './views/index.liquid'
  ]

  desc 'Generate all the stylesheets by copying or via Sass'
  task :stylesheets => FileList[
    './public/stylesheets/govuk-template.css',
    './public/stylesheets/govuk-template-print.css',
    './public/stylesheets/fonts.css',
    './public/stylesheets/application.css'
  ]

  desc 'Grab all the javascripts'
  task :javascripts => FileList[
    './public/javascripts/govuk-template.js',
    './public/javascripts/details.polyfill.js',
    './public/javascripts/jquery-1.11.3.js',
    './public/javascripts/govuk/shim-links-with-button-role.js',
    './public/javascripts/govuk/show-hide-content.js',
    './public/javascripts/ideal-postcodes-2.2.0.min.js',
    './public/javascripts/application.js'
  ]

  desc 'Grab all the images'
  task :images => FileList[
    './public/images/gov.uk_logotype_crown.png',
    './public/stylesheets/images/gov.uk_logotype_crown.png',
    './public/images/separator-2x.png',
    './public/stylesheets/images/open-government-licence_2x.png',
    './public/stylesheets/images/govuk-crest-2x.png',
    './public/stylesheets/images/open-government-licence.png',
    './public/stylesheets/images/govuk-crest.png',
    './public/images/images/hero-button/arrow.png',
    './public/images/images/hero-button/arrow@2x.png',
    './public/images/separator.png'
  ]

  # Map from a liquid file path to it's dependency
  def liquid_to_nunjucks liquid_file
    File.join VIEW_DIR, liquid_file.pathmap('%{views,}d/%n.html')
  end

  # Map from a dependency to it's liquid file
  def nunjucks_to_liquid nunjucks_file
    File.join '.\views', nunjucks_file.gsub(/html$/, 'liquid')
  end

  # Regex to detect what files are required in a nunjucks file
  INCLUDE_TAG = /\{% (?:extends|include) (?:'|")([^'"]+)(?:'|") %\}/m

  # Read the passed path and return an array of all liquid dependencies
  def grow_dependencies nunjucks_file
    nunjucks = File.read nunjucks_file
    liquid_dependencies = nunjucks.scan(INCLUDE_TAG).flatten.map &method(:nunjucks_to_liquid)
    [TRANSPILER_MODULES_DIR, nunjucks_file].concat liquid_dependencies
  end

  # When copying, create any missing directories
  def copyfile from, to
    FileUtils.mkdir_p File.dirname to
    cp from, to
  end

  # Convert to a .liquid file by passing through meta-template parser.
  # Automatically calculate the dependencies of the file by scanning it.
  # Also convert the includes in the resultant liquid to have .liquid extension
  rule '.liquid' => lambda {|p| grow_dependencies liquid_to_nunjucks p } do |file|
    FileUtils.mkdir_p File.dirname file.name
    command = "node ./meta-template/bin/parse.js --format jekyll #{file.sources[1]}"
    rake_output_message command
    liquid = `#{command}`
    File.write file.name, liquid.gsub(/\.html' %}/, '.liquid\' %}')
  end

  # Grab all stylesheets from the govuk modules dir
  rule /\.\/public\/stylesheets\/\S+\.css$/ => lambda {|p| File.join(GOVUK_ASSETS_DIR, 'stylesheets', p.pathmap('%f')) } do |file|
    copyfile file.source, file.name
  end

  # Build the application.css by running it through Sass
  file './public/stylesheets/application.css' => File.join(ASSETS_DIR, 'sass', 'application.scss') do |file|
    require 'sass'
    load_paths = [
      File.join(GOVUK_MODULES_DIR, 'govuk-elements-sass', 'public', 'sass'),
      File.join(GOVUK_MODULES_DIR, 'govuk_frontend_toolkit', 'stylesheets')]
    engine = Sass::Engine.for_file file.sources.first, load_paths: load_paths, cache: false
    File.write file.name, engine.render
  end

  # Grab all javascripts from the assets dir by default
  rule /\.\/public\/javascripts\/\S+\.js$/ => lambda {|p| File.join ASSETS_DIR, 'javascripts', p.pathmap('%f') } do |file|
    copyfile file.source, file.name
  end

  # Grab all govuk javascripts from the govuk dir
  rule /\.\/public\/javascripts\/govuk\/\S+\.js$/ => lambda {|p| File.join(GOVUK_MODULES_DIR, 'govuk_frontend_toolkit', 'javascripts', 'govuk', p.pathmap('%f')) } do |file|
    copyfile file.source, file.name
  end

  # Get the govuk-template.js from the modules dir
  file './public/javascripts/govuk-template.js' => File.join(GOVUK_ASSETS_DIR, 'javascripts', 'govuk-template.js') do |file|
    copyfile file.source, file.name
  end

  # Get all images from app assets dir
  rule /\.\/public\/\S+\.png$/ => lambda {|p| File.join ASSETS_DIR, 'images', p.pathmap('%f') } do |file|
    copyfile file.source, file.name
  end

  # Make sure module assets are installed before attempting to access them
  ANY_PROTOTYPE_ASSET = /^#{GOVUK_MODULES_DIR}.*/
  rule ANY_PROTOTYPE_ASSET => GOVUK_MODULES_DIR
end