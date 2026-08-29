function oldgcloud
  command docker run --rm --volumes-from gcloud-config gcr.io/google.com/cloudsdktool/google-cloud-cli:stable gcloud $argv
end
