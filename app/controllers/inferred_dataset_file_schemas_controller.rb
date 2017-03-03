class InferredDatasetFileSchemasController < ApplicationController
  def new
    @dataset_file_schema = DatasetFileSchema.new
    @inferred_dataset_file_schema = InferredDatasetFileSchema.new
    @s3_direct_post = S3_BUCKET.presigned_post(bucket_attributes)
  end

  def create
    infer = InferredDatasetFileSchema.new(create_params)
    if infer.valid?
      @dataset_file_schema = InferredDatasetFileSchemaCreationService.new(infer).perform
      redirect_to dataset_file_schemas_path
    else
      @s3_direct_post = S3_BUCKET.presigned_post(bucket_attributes)
      render :new
    end
  end

  private

  def bucket_attributes
    { key: "uploads/#{SecureRandom.uuid}/${filename}", success_action_status: '201', acl: 'public-read' }
  end

  def create_params
    params.require(:inferred_dataset_file_schema).permit(:name, :description, :user_id, :csv_url)
  end
end
