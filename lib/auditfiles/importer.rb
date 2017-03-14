# Base class for all importers. It defines the basic methods for parsing auditfiles.
# This class is inhereted for specific auditfile versions and software vendors.
#
# Importer
#   Adf
#     Adf1 (CLAIR1.00.00)
#       iMuis
#     Adf2
#   Xaf
#     Xaf2 (CLAIR2.00.00)
#     Xaf3
#
class Auditfiles::Importer
  def read
    raise 'Not implemented'
  end
end
