tenancy_ocid     = "ocid1.tenancy.oc1.."
user_ocid        = "ocid1. "
fingerprint      = "61:76:"
private_key_path = "~/.oci/oci_api_key.pem"
region           = "us-ashburn-1"

compartment_id   = "ocid1.tenancy.oc1.."

script_file_uri  = "oci://delta-copy-scripts@idfnvtzcpptm/Delta_Incremental_Copy.py"
logs_bucket_uri  = "oci://dataflow-logs@idfnvtzcpptm/"

source_path      = "oci://delta-copy-source@idfnvtzcpptm/delta_table"
dest_path        = "oci://delta-copy-dest@idfnvtzcpptm/delta_table"
time_column      = "load_timestamp"
tenancy_column   = "tenancy_id"
lookback_days    = 30

