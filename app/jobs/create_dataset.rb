class CreateDataset
  include Sidekiq::Worker
  sidekiq_options retry: false

	def perform(dataset_params, files, user_id, options = {})
		Rails.logger.info "CreateDataset: In perform"
		files = [files] if files.class == Hash
		shapefile = false

		user = find_user(user_id)
		@dataset = new_dataset_for_user(user)

		@dataset.assign_attributes(ActiveSupport::HashWithIndifferentAccess.new(
			dataset_params.merge(job_id: self.jid)
		))

		@dataset.publisher_name = @dataset.owner
		@dataset.publisher_url  = @dataset.github_url

		files.each do |dataset_file_creation_hash|

			dataset_file = DatasetFile.create(dataset_file_creation_hash)

			if !dataset_file_creation_hash["schema"] && dataset_file.file_type == '.csv'
				CsvlintValidateService.validate_csv(dataset_file)
			end

			if dataset_file_creation_hash["schema"]
				schema = create_schema(dataset_file_creation_hash, user)

				dataset_file.dataset_file_schema = schema
				dataset_file.save
			elsif dataset_file_creation_hash["dataset_file_schema_id"]
				dataset_file.dataset_file_schema_id = dataset_file_creation_hash["dataset_file_schema_id"]
			end

			@dataset.dataset_files << dataset_file
		end

		@dataset.dataset_files << ShapefileToGeojsonService.new(@dataset).convert if @dataset.is_shapefile

		@dataset.report_status(options["channel_id"])
	end

  def find_user(user_id)
    User.find(user_id)
  end

  def new_dataset_for_user(user)
    user.datasets.new
  end

	def create_schema(dataset_file_creation_hash, user)
		schema = DatasetFileSchemaService.new(
			dataset_file_creation_hash["schema_name"],
			dataset_file_creation_hash["schema_description"],
			dataset_file_creation_hash["schema"],
			user,
			user.name,
			dataset_file_creation_hash["schema_restricted"]
		).create_dataset_file_schema
	end

	private

	def is_csv?(file)
		file_extension(file) == ".csv"
	end

	def is_shapefile?(file)
		file_extension(file) == ".shp"
	end

	def file_extension(file)
		file_ext = file.storage_key || file.file.original_filename || ''
		File.extname(file_ext)
	end

end

# Results from Files array - just what's required
# [
#     [0] {
#                                   "title" => "Fri1414",
#                             "description" => "Fri1414",
#                                    "file" => "https://jj-octopub-development.s3-eu-west-1.amazonaws.com/uploads/ef2d221a-3210-40c0-af49-0bfe39b139be/australian-open-data-publishers.csv",
#         "existing_dataset_file_schema_id" => "",
#                             "schema_name" => "Fri1414",
#                      "schema_description" => "Fri1414",
#                                  "schema" => "https://jj-octopub-development.s3-eu-west-1.amazonaws.com/uploads/ef2d221a-3210-40c0-af49-0bfe39b139be/schema.json"
#     }
# ]
