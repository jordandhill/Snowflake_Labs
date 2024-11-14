

-------------------------------------------
--       Create Required Objects         --
-------------------------------------------

USE ROLE ACCOUNTADMIN;

---create a gpu pool
CREATE COMPUTE POOL gpu_smallest
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = GPU_NV_S;

CREATE COMPUTE POOL gpu_medium
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = GPU_NV_M;

---create a database and schema
create OR REPLACE role MY_FINETUNING_ROLE;  
CREATE OR REPLACE DATABASE MY_FINETUNING_DB;
USE DATABASE MY_FINETUNING_DB;
CREATE SCHEMA NOTEBOOKS;

---allow connections to hugging face to download the Stable Diffusion model
CREATE OR REPLACE NETWORK RULE huggin_network_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('huggingface.co','cdn-lfs-us-1.huggingface.co','cdn-lfs.huggingface.co','cdn-lfs.hf.co', 'cdn-lfs-us-1.hf.co');


create or replace secret my_hf_access_token 
type = 'GENERIC_STRING' 
SECRET_STRING = 'XXXXXXXXXX'; ---<<<!!! REPLACE WITH YOUR TOKEN !!!
  
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION HUGGIN_ACCESS_INTEGRATION
  ALLOWED_NETWORK_RULES = (huggin_network_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (my_hf_access_token)
  ENABLED = true;


CREATE OR REPLACE FUNCTION get_hf_key()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.9
HANDLER = 'retrieve_hf_key'
EXTERNAL_ACCESS_INTEGRATIONS = (HUGGIN_ACCESS_INTEGRATION)
SECRETS = ('cred' = my_hf_access_token)
AS
$$
import _snowflake
def retrieve_hf_key():   
  my_api_key = _snowflake.get_generic_secret_string('cred') 
  return my_api_key
$$;



--for pip install, be able to download libraries
CREATE OR REPLACE NETWORK RULE pypi_network_rule
MODE = EGRESS
TYPE = HOST_PORT
VALUE_LIST = ('pypi.org', 'pypi.python.org', 'pythonhosted.org',  'files.pythonhosted.org');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION pypi_access_integration
ALLOWED_NETWORK_RULES = (pypi_network_rule)
ENABLED = true;

--for pip install from github (or if you want to push/pull code with github)
CREATE OR REPLACE NETWORK RULE github_network_rule
MODE = EGRESS
TYPE = HOST_PORT
VALUE_LIST = ('github.com');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION github_access_integration
ALLOWED_NETWORK_RULES = (github_network_rule)
ENABLED = true;

--api integrations allows us to push/pull to a repo
create api integration git_api_integration
    api_provider = git_https_api
    api_allowed_prefixes = ('https://github.com/jordandhill/Snowflake_Labs.git')
    enabled = true;

  
--create a default warehouse for compute
CREATE OR REPLACE WAREHOUSE MY_DEFAULT_XS_WH;

--create a place to store models & images
CREATE OR REPLACE STAGE artifacts;

---------------------------------------------
--       Grant Required Privileges         --
---------------------------------------------

-- we grant only necessary privileges to a custom role for development

GRANT USAGE on INTEGRATION HUGGIN_ACCESS_INTEGRATION to ROLE MY_FINETUNING_ROLE;
GRANT USAGE on INTEGRATION pypi_access_integration to ROLE MY_FINETUNING_ROLE; 
GRANT USAGE on INTEGRATION github_access_integration to ROLE MY_FINETUNING_ROLE; 
GRANT USAGE on INTEGRATION git_api_integration to ROLE MY_FINETUNING_ROLE;
GRANT USAGE on compute pool gpu_smallest to role MY_FINETUNING_ROLE;
GRANT USAGE on compute pool gpu_medium to role MY_FINETUNING_ROLE;
GRANT USAGE on WAREHOUSE MY_DEFAULT_XS_WH to role MY_FINETUNING_ROLE;
GRANT OWNERSHIP ON DATABASE MY_FINETUNING_DB TO ROLE MY_FINETUNING_ROLE;
GRANT OWNERSHIP ON SCHEMA MY_FINETUNING_DB.NOTEBOOKS TO ROLE MY_FINETUNING_ROLE REVOKE CURRENT GRANTS;

GRANT CREATE NOTEBOOK ON SCHEMA MY_FINETUNING_DB.NOTEBOOKS TO ROLE MY_FINETUNING_ROLE;
GRANT USAGE ON SECRET MY_HF_ACCESS_TOKEN TO ROLE MY_FINETUNING_ROLE;

--and grant that role to the developer(s)
GRANT ROLE MY_FINETUNING_ROLE to USER MY_USER; ---<<<!!! REPLACE WITH YOUR ACCOUNT OR DEV ACCOUNT !!!

grant usage  ON database MY_FINETUNING_DB to role accountadmin;

use role MY_FINETUNING_ROLE;
use database MY_FINETUNING_DB;
use schema NOTEBOOKS;

--create the link to the repository on git to push/pull the notebook  
CREATE GIT REPOSITORY Snowflake_Labs
  API_INTEGRATION = git_api_integration
--  GIT_CREDENTIALS = myco_git_secret
  ORIGIN = 'https://github.com/jordandhill/Snowflake_Labs.git';
