# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "y2packager/licenses_fetchers/base"

module Y2Packager
  module LicensesFetchers
    # This class is responsible for obtaining the license and license content
    # of a given product from libzypp.
    class Libzypp < Base
      # Return the license text to be confirmed
      #
      # @param lang [String] Language
      # @return [String,nil] Product's license; nil if the product or the license were not found.
      def content(lang)
        Yast::Pkg.PrdGetLicenseToConfirm(product_name, lang)
      end
    end
  end
end
