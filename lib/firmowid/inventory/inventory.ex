defmodule Firmowid.Inventory do
  @moduledoc """
  Ash domain for the company's equipment inventory: the items it owns and the
  history of who held each of them.

  Only admins manage equipment; an employee reads the equipment they hold.
  """

  use Ash.Domain,
    extensions: [Ash.Policy.Authorizer]

  alias Firmowid.Checks.ActorRole
  alias Firmowid.Inventory.Equipment
  alias Firmowid.Inventory.EquipmentAssignment

  resources do
    resource Equipment do
      define :read_equipment, action: :read
      define :list_equipment, action: :list
      define :get_equipment, action: :get, get_by: [:id]
      define :create_equipment, action: :create
      define :update_equipment, action: :update
    end

    resource EquipmentAssignment do
      define :read_equipment_assignments, action: :read
      define :list_equipment_assignments, action: :list
      define :issue_equipment, action: :issue
      define :return_equipment, action: :return
    end
  end

  policies do
    bypass {ActorRole, role: :admin} do
      authorize_if always()
    end
  end

  authorization do
    authorize :by_default
    require_actor? true
  end
end
