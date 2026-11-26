defmodule FirmowidWeb.Inventory.InventoryTest do
  @moduledoc false
  use FirmowidWeb.ConnCase, async: true

  import Firmowid.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Firmowid.Inventory
  alias Firmowid.Scope

  test "admin adds a laptop, issues it once, takes it back and sees its history", %{conn: conn} do
    admin = admin_fixture()
    org_id = admin.member.organization_id
    employee = user_in_org_fixture(org_id, %{role: :employee})
    other = user_in_org_fixture(org_id, %{role: :employee})
    scope = %Scope{actor: admin, tenant: org_id}
    conn = log_in_user(conn, admin)

    {:ok, form, _html} = live(conn, ~p"/zarzadzanie/sprzet/dodaj")

    {:ok, view, _html} =
      form
      |> form("#equipment-form",
        equipment: %{name: "MacBook Pro 14", kind: "laptop", serial_number: "ABC123"}
      )
      |> render_submit()
      |> follow_redirect(conn)

    [laptop] = Inventory.list_equipment!(%{}, scope: scope)

    view |> element("button", "Issue to an employee") |> render_click()

    view
    |> form("#issue-equipment-form",
      issue: %{member_id: employee.member.id, issue_note: "z ładowarką"}
    )
    |> render_submit()

    assert render(view) =~ "z ładowarką"
    refute has_element?(view, "button", "Issue to an employee")

    # Another admin's stale form cannot issue the same laptop twice.
    assert {:error, _error} =
             Inventory.issue_equipment(%{equipment_id: laptop.id, member_id: other.member.id},
               scope: scope
             )

    view |> element("button", "Record the return") |> render_click()

    view
    |> form("#return-equipment-form", return: %{return_note: "rysa na klapie"})
    |> render_submit()

    assert render(view) =~ "rysa na klapie"
    assert has_element?(view, "button", "Issue to an employee")

    assert [%{returned_on: %Date{}}] =
             Inventory.list_equipment_assignments!(%{equipment_id: laptop.id}, scope: scope)
  end

  test "an employee sees only the equipment they hold and cannot open the inventory", %{
    conn: conn
  } do
    admin = admin_fixture()
    org_id = admin.member.organization_id
    employee = user_in_org_fixture(org_id, %{role: :employee})
    other = user_in_org_fixture(org_id, %{role: :employee})
    scope = %Scope{actor: admin, tenant: org_id}

    mine = Inventory.create_equipment!(%{name: "ThinkPad T14"}, scope: scope)
    theirs = Inventory.create_equipment!(%{name: "Dell XPS 13"}, scope: scope)

    Inventory.issue_equipment!(%{equipment_id: mine.id, member_id: employee.member.id},
      scope: scope
    )

    Inventory.issue_equipment!(%{equipment_id: theirs.id, member_id: other.member.id},
      scope: scope
    )

    conn = log_in_user(conn, employee)

    assert {:error, {:redirect, _redirect}} = live(conn, ~p"/zarzadzanie/sprzet")

    {:ok, _view, html} = live(conn, ~p"/ustawienia/sprzet")
    assert html =~ "ThinkPad T14"
    refute html =~ "Dell XPS 13"
  end
end
