defmodule Firmowid.Inventory.Equipment do
  @moduledoc """
  A piece of company equipment, such as a laptop, that an admin issues to
  members.

  Whoever holds it is its open assignment (`current_assignment`); without one
  it is available. Admins manage equipment through the domain bypass; an
  employee reads only the equipment they hold now.
  """
  use Ash.Resource,
    domain: Firmowid.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Firmowid.Inventory.EquipmentAssignment
  alias Firmowid.Resource

  require Resource

  @kinds [:laptop, :phone, :monitor, :other]

  postgres do
    table "equipment"
    repo Firmowid.Repo

    references do
      reference :organization, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    read :get do
      description "Get one piece of equipment with its holder and its whole history."
      get? true

      prepare build(
                load: [
                  current_assignment: [member: [:display_name]],
                  assignments: [member: [:display_name]]
                ]
              )
    end

    read :list do
      description "List equipment by name with its current holder, optionally only the available or the issued."

      argument :status, :atom do
        constraints one_of: [:available, :issued]
      end

      prepare build(sort: [name: :asc], load: [current_assignment: [member: [:display_name]]])

      prepare build(filter: expr(not exists(assignments, is_nil(returned_on)))) do
        where argument_equals(:status, :available)
      end

      prepare build(filter: expr(exists(assignments, is_nil(returned_on)))) do
        where argument_equals(:status, :issued)
      end
    end

    create :create do
      description "Add equipment to the inventory."
      accept [:name, :kind, :serial_number]
    end

    update :update do
      description "Change the name, kind or serial number of equipment."
      primary? true
      accept [:name, :kind, :serial_number]
    end
  end

  # Writes are left to the domain's admin bypass.
  policies do
    policy action_type(:read) do
      authorize_if expr(
                     exists(
                       assignments,
                       is_nil(returned_on) and member_id == ^actor([:member, :id])
                     )
                   )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100
    end

    attribute :kind, :atom do
      public? true
      allow_nil? false
      default :laptop
      constraints one_of: @kinds
    end

    attribute :serial_number, :string do
      public? true
      constraints max_length: 100
    end

    Resource.firmowid_timestamps()
  end

  relationships do
    belongs_to :organization, Firmowid.Core.Organization do
      allow_nil? false
    end

    has_many :assignments, EquipmentAssignment do
      sort issued_on: :desc, inserted_at: :desc
    end

    has_one :current_assignment, EquipmentAssignment do
      description "The assignment that is not returned yet; at most one exists."
      filter expr(is_nil(returned_on))
    end
  end

  @doc "The kinds of equipment, in the order the form offers them."
  @spec kinds() :: [atom()]
  def kinds, do: @kinds
end
