module Api
  module V1
    class WarehousesController < BaseController
      before_action :set_warehouse, only: [:show, :update, :destroy]

      # GET /api/v1/warehouses
      def index
        @warehouses = Warehouse.all
        render_success(@warehouses)
      end

      # GET /api/v1/warehouses/:id
      def show
        render_success(@warehouse)
      end

      # POST /api/v1/warehouses
      def create
        @warehouse = Warehouse.new(warehouse_params)

        if @warehouse.save
          render_success(@warehouse, :created)
        else
          render_error(@warehouse.errors.full_messages.join(', '))
        end
      end

      # PUT /api/v1/warehouses/:id
      def update
        if @warehouse.update(warehouse_params)
          render_success(@warehouse)
        else
          render_error(@warehouse.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/warehouses/:id
      def destroy
        @warehouse.destroy
        render_success({ message: 'Warehouse deleted successfully' })
      end

      private

      def set_warehouse
        @warehouse = Warehouse.find(params[:id])
      end

      def warehouse_params
        params.require(:warehouse).permit(
          :name, :code, :address_line1, :address_line2, :city, :state,
          :postal_code, :country, :phone_number, :email, :contact_person,
          :active, :notes, :latitude, :longitude
        )
      end
    end
  end
end
