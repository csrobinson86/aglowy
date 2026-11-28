class ApplicationJob < ActiveJob::Base
  # A job whose record was deleted before it ran has nothing left to do.
  discard_on ActiveJob::DeserializationError

  private
    # A recurring job's loop: one record that fails is reported and the rest still run, since nothing retries a
    # recurring job before its next run. The report names the job and the record's GlobalID, never anything personal.
    def each_reporting_failures(records)
      records.find_each do |record|
        yield record
      rescue StandardError => error
        Rails.error.report(error, context: { job: self.class.name, record: record.to_gid.to_s })
      end
    end
end
