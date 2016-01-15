open OUnit2
open Soup

(* For pre-4.01 distributions of OCaml. *)
let (|>) x f = f x

let map_option f = function
  | None -> None
  | Some v -> Some (f v)

let page : string -> string =
  let table = Hashtbl.create 7 in

  let directory = "test/pages" in
  Sys.readdir directory
  |> Array.iter (fun file ->
    let contents = file |> Filename.concat directory |> read_file in
    Hashtbl.replace table file contents);

  fun page_name -> Hashtbl.find table page_name

let suites = [
  "lambda-soup" >::: [
    ("normal_return" >:: fun _ ->
      assert_equal (with_stop (fun _ -> 0)) 0;
      assert_equal (with_stop (fun _ -> "a")) "a");

    ("early_return" >:: fun _ ->
      assert_equal (with_stop (fun stop -> stop.throw 0 |> ignore; 1)) 0;
      assert_equal (with_stop (fun stop -> stop.throw "a" |> ignore; "b")) "a");

    ("nested_stop" >:: fun _ ->
      assert_equal
        (with_stop (fun stop ->
          with_stop (fun _ ->
            stop.throw 0 |> ignore; 1) + 1))
        0);

    ("require_fails" >:: fun _ ->
      (try require None |> ignore; false with | Failure _ -> true | _ -> false)
      |> assert_bool "expected Failure");

    ("parse-select-list" >:: fun _ ->
      let soup = page "list" |> parse in
      let test selector expected_count =
        assert_equal ~msg:selector
          (soup |> select selector |> count) expected_count
      in

      test "li" 5;
      test "ul li" 3;
      test "ol li" 2;
      test "body li" 5;
      test "body > li" 0;
      test "body > *" 3;
      test "ul > li" 3;
      test "* > li" 5;
      test "* li" 5;
      test "[id=one]" 1;
      test "[id=six]" 0;
      test "li[id]" 5;
      test "ul[id]" 0;
      test "li[id=two]" 1;
      test ".odd" 3;
      test ".even" 2;
      test "li.odd" 3;
      test "body.odd" 0;
      test "#one" 1;
      test "li#one" 1;
      test "ul#one" 0;
      test "li[class~=odd]" 3;
      test "li[id^=t]" 2;
      test "li[id$=e]" 3;
      test "li[id*=n]" 1;
      test "li:nth-child(1)" 2;
      test "li:nth-child(3)" 1;
      test "ul li ~ li" 2;
      test "li ~ li" 3;
      test "li + li" 3;
      test ":root" 1;
      test "html:root" 1;
      test "li:root" 0;
      test "ul li:nth-child(1) + li" 1;
      test "ul li:nth-child(3) + li" 0;
      test "ul li:nth-child(even)" 1;
      test "ul li:nth-child(odd)" 2;
      test "ul li:nth-child(2n)" 1;
      test "ul li:nth-child(2n)#two" 1;
      test "ul li:nth-child(2n+1)" 2;
      test "ul li:nth-child(2n+1)#one" 1;
      test "ul li:nth-child(2n+1)#three" 1;
      test "ul li:nth-child(2n+1)#two" 0;
      test "li:nth-last-child(1)" 2;
      test "ul li:nth-last-child(1)" 1;
      test "ul li:nth-last-child(odd)" 2;
      test "ul:nth-of-type(1)" 1;
      test "ul:nth-of-type(2)" 0;
      test "ul:nth-last-of-type(1)" 1;
      test "li:first-child" 2;
      test "li:first-of-type" 2;
      test "li:contains(\"Item\")" 5;
      test "li:contains(\"5\")" 1;
      test "li:empty" 0;
      test "p:empty" 1;
      test "ul li:not(:nth-child(1))" 2;
      test ":not(ul) > li" 2;
      test
        ("html:root > body.lists[class~=lists] > ul > li#one:nth-child(1) " ^
         "+ li#two")
        1);

    ("parse-select-html5" >:: fun _ ->
      let soup = page "html5" |> parse in
      let test selector expected_count =
        assert_equal ~msg:selector (soup $$ selector |> count) expected_count
      in

      test "nav" 1;
      test "nav a" 2;
      test "header" 1;
      test "main" 1;
      test "section" 1;
      test "article" 2;
      test "footer" 1);

    ("parse-select-google" >:: fun _ ->
      assert_equal (page "google" |> parse $$ "form[action]" |> count) 1);

    ("generalized-select" >:: fun _ ->
      let soup = page "list" |> parse in
      let test root selector expected_count =
        assert_equal ~msg:selector
          (root |> select selector |> count) expected_count
      in

      test (soup $ "html") "" 1;
      test (soup $ "ul") "+ ol" 1;
      test (soup $ "ul") "+ p" 0;
      test (soup $ "ul") "~ p" 1;
      test (soup $ "ul") "~ *" 2;
      test (soup $ "body") "> *" 3);

    ("select-attribute-operators" >:: fun _ ->
      let soup = "<form action=\"/continue\"></form>" |> parse in
      assert_equal (soup $$ "form[action=/continue]" |> count) 1);

    ("select_one" >:: fun _ ->
      let soup = page "list" |> parse in
      let present selector =
        assert_bool selector ((soup $? selector) <> None)
      in
      let absent selector =
        assert_bool selector ((soup $? selector) = None)
      in

      present "li";
      absent "div";
      present "ol";
      absent "ol:first-child";
      present "ul:first-child";
      present "ul:first-of-type";
      absent "ul:nth-of-type(2)";
      present "ol + p";
      absent "ul + p";
      present "ul ~ p");

    ("element-name" >:: fun _ ->
      let soup = page "list" |> parse in
      let has_name selector name' =
        assert_equal ~msg:selector (soup $ selector |> name) name'
      in

      has_name "html" "html";
      has_name "body" "body";
      has_name "#two" "li");

    ("attribute" >:: fun _ ->
      let soup = page "list" |> parse in

      let has selector attr =
        assert_bool selector (soup $ selector |> has_attribute attr)
      in

      let doesn't_have selector attr =
        assert_bool selector (soup $ selector |> has_attribute attr |> not)
      in

      has "body" "class";
      has "[class]" "class";
      has "li" "id";
      doesn't_have "body" "id";

      let value selector attr value =
        assert_equal ~msg:selector (soup $ selector |> attribute attr) value
      in

      value "body" "class" (Some "lists");
      value "li#two" "id" (Some "two");
      value "html" "id" None;

      let classes selector class_list =
        assert_equal ~msg:selector (soup $ selector |> classes) class_list
      in

      classes "p" ["a"; "b"];
      classes "html" [];
      classes "li:nth-child(1)" ["odd"];

      let id selector value =
        assert_equal ~msg:selector (soup $ selector |> id) value
      in

      id "li:nth-child(2)" (Some "two");
      id "body" None);

    ("element-coerce" >:: fun _ ->
      let soup = page "list" |> parse in

      let list = soup $ "ul" in
      let item = list |> children |> elements |> R.first in

      assert_bool "is_element" (is_element item);
      assert_bool "element" (element item <> None);

      let item_text = item |> children |> R.first in

      assert_bool "not is_element" (is_element item_text |> not);
      assert_bool "element is None" (element item_text = None));

    ("content-access" >:: fun _ ->
      let soup = page "list" |> parse in

      assert_equal (soup $ "li#one" |> leaf_text) (Some "Item 1");

      assert_equal
        (soup $ "li#one" |> children |> R.first |> leaf_text)
        (Some "Item 1");

      assert_equal (soup $ "ul" |> leaf_text) None;

      assert_equal (soup $ "li#one" |> texts) ["Item 1"];

      assert_equal
        (soup $ "ul" |> texts)
        ["\n  "; "Item 1"; "\n  "; "Item 2"; "\n  "; "Item 3"; "\n"];

      assert_equal
        (soup $ "ul" |> trimmed_texts)
        ["Item 1"; "Item 2"; "Item 3"]);

    ("leaf_text-whitespace" >:: fun _ ->
      let soup = "<p> <span> <em>foobar</em> </span> </p>" |> parse in
      assert_equal (leaf_text soup) (Some "foobar"));

    ("children-traversal" >:: fun _ ->
      let soup = page "list" |> parse in

      let expected_count selector n =
        assert_equal ~msg:selector (soup $ selector |> children |> count) n
      in

      expected_count "ul" 7;
      expected_count "li" 1;
      expected_count "p" 0;

      assert_equal (soup |> children |> count) 2;
      assert_equal (soup $ "li" |> children |> R.first |> children |> count) 0;

      assert_equal (soup |> children |> R.first |> R.element |> name) "html";

      assert_equal
        (soup $ "body" |> children |> R.nth 2 |> R.element |> name) "ul";

      assert_equal
        (soup $ "body" |> children |> R.nth 4 |> R.element |> name) "ol");

    ("elements-filter" >:: fun _ ->
      let soup = page "list" |> parse in
      let all_children = soup $ "ul" |> children in

      assert_equal (all_children |> count) 7;
      assert_bool "first child not element"
        (all_children |> R.first |> is_element |> not);

      let only_elements = all_children |> elements in

      assert_equal (only_elements |> count) 3;

      let is_list_item n =
        assert_equal (only_elements |> R.nth n |> name) "li"
      in

      is_list_item 1;
      is_list_item 2;
      is_list_item 3);

    ("descendants-traversal" >:: fun _ ->
      let soup = page "list" |> parse in

      let expected_count selector n =
        assert_equal ~msg:selector (soup $ selector |> descendants |> count) n
      in

      expected_count "li" 1;
      expected_count "p" 0;
      expected_count "ul" 10;
      expected_count "ol" 7;
      expected_count "body" 24;
      expected_count "html" 27;

      assert_equal (soup |> descendants |> count) 29;

      assert_equal
        (soup $ "body" |> descendants |> elements |> to_list |> List.map name)
        ["ul"; "li"; "li"; "li"; "ol"; "li"; "li"; "p"]);

    ("ancestors-traversal" >:: fun _ ->
      let soup = page "list" |> parse in

      let expected_tags selector tags =
        assert_equal ~msg:selector
          (soup $ selector |> ancestors |> to_list |> List.map name)
          tags
      in

      expected_tags "html" [];
      expected_tags "body" ["html"];
      expected_tags "ul" ["body"; "html"];
      expected_tags "li" ["ul"; "body"; "html"];

      assert_equal
        (soup $ "li" |> children |> R.first |> ancestors
         |> to_list |> List.map name)
        ["li"; "ul"; "body"; "html"];

      assert_equal (soup |> ancestors |> to_list) []);

    ("next-siblings-traversal" >:: fun _ ->
      let soup = page "list" |> parse in

      let expected_count selector n =
        assert_equal ~msg:selector (soup $ selector |> next_siblings |> count) n
      in

      expected_count "html" 1;
      expected_count "ul" 5;

      assert_equal
        (soup $ "body" |> children |> R.first |> next_siblings |> count) 6;

      assert_equal
        (soup $ "ul" |> next_siblings |> elements |> to_list |> List.map name)
        ["ol"; "p"]);

    ("previous-siblings-traversal" >:: fun _ ->
      let soup = page "list" |> parse in

      let expected_count selector n =
        assert_equal ~msg:selector
          (soup $ selector |> previous_siblings |> count)
          n
      in

      expected_count "html" 0;
      expected_count "ul" 1;
      expected_count "p" 5;

      let expected_count_at_nth_child selector n count' =
        assert_equal ~msg:selector
          (soup $ selector |> children |> R.nth n |> previous_siblings |> count)
          count'
      in

      expected_count_at_nth_child "body" 1 0;
      expected_count_at_nth_child "body" 3 2;

      assert_equal
        (soup $ "p" |> previous_siblings |> elements
         |> to_list |> List.map name)
        ["ol"; "ul"]);

    ("to_list" >:: fun _ ->
      assert_equal
        (page "list" |> parse |> descendants |> elements
         |> to_list |> List.map name)
        ["html"; "body"; "ul"; "li"; "li"; "li"; "ol"; "li"; "li"; "p"]);

    ("fold" >:: fun _ ->
      let soup = page "list" |> parse in

      assert_equal (soup |> descendants |> fold (fun v _ -> v + 1) 0) 29;

      assert_equal
        (soup |> descendants |> elements
         |> fold (fun l e -> (name e)::l) [] |> List.rev)
        ["html"; "body"; "ul"; "li"; "li"; "li"; "ol"; "li"; "li"; "p"]);

    ("filter" >:: fun _ ->
      assert_equal
        (page "list" |> parse |> descendants |> elements
         |> filter (fun e -> e |> children |> elements |> count = 0)
         |> to_list |> List.map name)
        ["li"; "li"; "li"; "li"; "li"; "p"]);

    ("map" >:: fun _ ->
      assert_equal
        (page "list" |> parse $$ "body *"
         |> map (fun e -> e |> ancestors |> R.first)
         |> to_list |> List.map name)
        ["body"; "ul"; "ul"; "ul"; "body"; "ol"; "ol"; "body"]);

    ("filter_map" >:: fun _ ->
      assert_equal
        (page "list" |> parse |> descendants
         |> filter_map element |> to_list |> List.map name)
        ["html"; "body"; "ul"; "li"; "li"; "li"; "ol"; "li"; "li"; "p"]);

    ("flatten" >:: fun _ ->
      assert_equal
        (page "list" |> parse $ "body" |> children
         |> flatten (fun node -> children node |> elements)
         |> to_list |> List.map R.id)
        ["one"; "two"; "three"; "four"; "five"]);

    ("iter" >:: fun _ ->
      let tags = ref [] in

      page "list" |> parse |> descendants |> elements
      |> iter (fun e -> tags := (name e)::!tags);

      assert_equal
        (List.rev !tags)
        ["html"; "body"; "ul"; "li"; "li"; "li"; "ol"; "li"; "li"; "p"]);

    ("projection" >:: fun _ ->
      let nodes = page "list" |> parse $ "body" |> children |> elements in

      let test f maybe_name =
        assert_equal (nodes |> f |> map_option name) maybe_name
      in

      test (nth 1) (Some "ul");
      test (nth 2) (Some "ol");
      test (nth 3) (Some "p");
      test (nth 0) None;
      test (nth 4) None;

      test first (Some "ul");
      test last (Some "p");

      assert_equal (nodes |> count) 3);

    ("index_of" >:: fun _ ->
      let soup = page "list" |> parse in

      let test f selector index =
        assert_equal ~msg:selector (soup $ selector |> f) index
      in

      test index_of "html" 1;
      test index_of "body" 2;
      test index_of "ul" 2;
      test index_of "ol" 4;
      test index_of "p" 6;

      test index_of_element "html" 1;
      test index_of_element "body" 1;
      test index_of_element "ul" 1;
      test index_of_element "ol" 2;
      test index_of_element "p" 3);

    ("tags" >:: fun _ ->
      let soup = page "list" |> parse in

      assert_equal
        (soup |> tags "li" |> to_list |> List.map R.id)
        ["one"; "two"; "three"; "four"; "five"];

      assert_equal (soup |> R.tag "p" |> name) "p";
      assert_equal (soup |> tag "q") None);

    ("parent" >:: fun _ ->
      let soup = page "list" |> parse in

      let test selector maybe_parent_name =
        assert_equal
          (soup $ selector |> parent |> map_option name)
          maybe_parent_name
      in

      test "html" None;
      test "body" (Some "html");
      test "ul" (Some "body");
      test "ol" (Some "body"));

    ("child" >:: fun _ ->
      let soup = page "list" |> parse in

      let test f selector value =
        assert_equal ~msg:selector
          (soup $ selector |> f |> map_option (fun node ->
            match element node with
            | None -> R.leaf_text node
            | Some e -> name e))
          value
      in

      test child "body" (Some "\n\n");
      test child_element "body" (Some "ul"));

    ("sibling" >:: fun _ ->
      let soup = page "list" |> parse in

      let test f selector index =
        assert_equal (soup $ selector |> f |> map_option index_of) index
      in

      test next_sibling "ul" (Some 3);
      test previous_sibling "ul" (Some 1);
      test next_element "ul" (Some 4);
      test previous_element "ol" (Some 2));

    ("child-predicate" >:: fun _ ->
      let soup = page "list" |> parse in

      let test f selector value = assert_equal (soup $ selector |> f) value in

      test no_children "p" true;
      test no_children "li" false;
      test at_most_one_child "li" true;
      test at_most_one_child "ul" false);

    ("is_root" >:: fun _ ->
      let soup = page "list" |> parse in

      assert_bool "soup" (soup |> is_root |> not);
      assert_bool "html" (soup $ "html" |> is_root);
      assert_bool "body" (soup $ "body" |> is_root |> not);

      let bare = create_element "p" in
      let child = create_element "a" in
      append_child bare child;

      assert_bool "p" (bare |> is_root);
      assert_bool "a" (bare $ "a" |> is_root |> not));

    ("create_element" >:: fun _ ->
      let element = create_element "p" in
      set_attribute "id" "foo" element;
      set_attribute "class" "foo bar" element;

      assert_bool "is_element" (is_element element);
      assert_equal (name element) "p";

      set_name "li" element;

      assert_equal (element |> name) "li";
      assert_equal (element |> id) (Some "foo");
      assert_equal (element |> attribute "id") (Some "foo");
      assert_equal (element |> classes) ["foo"; "bar"];
      assert_equal (element |> attribute "class") (Some "foo bar");
      assert_equal (element |> parent) None;
      assert_equal (element |> children |> count) 0);

    ("create_text" >:: fun _ ->
      let node = create_text "foo" in

      assert_bool "not is_element" (is_element node |> not);
      assert_equal (node |> leaf_text) (Some "foo");
      assert_equal (node |> texts) ["foo"];
      assert_equal (node |> parent) None;
      assert_equal (node |> children |> count) 0);

    ("create_soup" >:: fun _ ->
      let soup = create_soup () in

      assert_bool "not is_element" (is_element soup |> not);
      assert_equal (soup |> children |> count) 0);

    ("create_element-fancy" >:: fun _ ->
      let element =
        create_element ~attributes:["href", "#"; "id", "here"] "a" in

      assert_equal (attribute "href" element) (Some "#");
      assert_equal (attribute "id" element) (Some "here");
      assert_equal (attribute "class" element) None;

      let element = create_element ~classes:["foo"; "bar"] "div" in

      assert_bool "has class" (classes element |> List.mem "foo");
      assert_bool "has class" (classes element |> List.mem "bar");
      assert_bool "doesn't have class"
        (classes element |> List.mem "lulz" |> not);

      let element = create_element ~class_:"foo" "div" in

      assert_bool "has class" (classes element |> List.mem "foo");
      assert_bool "doesn't have class"
        (classes element |> List.mem "lulz" |> not);

      let element = create_element ~id:"foo" "div" in

      assert_equal (attribute "id" element) (Some "foo");

      let element = create_element ~inner_text:"Foo" "div" in

      assert_equal (leaf_text element) (Some "Foo");
      assert_equal (children element |> count) 1);

    ("insert_children" >:: fun _ ->
      let element = create_element "p" in

      let node1 = create_text "one" in
      append_child element node1;

      let node2 = create_text "two" in
      append_child element node2;
      assert_equal (node2 |> parent |> map_option name) (Some "p");
      assert_equal (element |> children |> count) 2;
      assert_equal (node1 |> index_of) 1;
      assert_equal (node2 |> index_of) 2;

      let node3 = create_text "three" in
      prepend_child element node3;
      assert_equal (node3 |> parent |> map_option name) (Some "p");
      assert_equal (element |> children |> count) 3;
      assert_equal (node3 |> index_of) 1;
      assert_equal (node1 |> index_of) 2;
      assert_equal (node2 |> index_of) 3;

      let node4 = create_text "four" in
      insert_at_index 2 element node4;
      assert_equal (node4 |> parent |> map_option name) (Some "p");
      assert_equal (element |> children |> count) 4;
      assert_equal (node3 |> index_of) 1;
      assert_equal (node4 |> index_of) 2;
      assert_equal (node1 |> index_of) 3;
      assert_equal (node2 |> index_of) 4;

      let node5 = create_text "five" in
      insert_before node3 node5;
      assert_equal (node5 |> parent |> map_option name) (Some "p");
      assert_equal (element |> children |> count) 5;
      assert_equal (node5 |> index_of) 1;

      let node6 = create_text "six" in
      insert_after node1 node6;
      assert_equal (node6 |> parent |> map_option name) (Some "p");
      assert_equal (element |> children |> count) 6;
      assert_equal (node6 |> index_of) 5;

      let node7 = create_soup () in
      let some_text = create_text "seven" in
      append_root node7 some_text;
      assert_equal (some_text |> parent) None;
      assert_equal (node7 |> children |> count) 1;

      insert_at_index 20 element node7;
      assert_equal (node7 |> children |> count) 0;
      assert_equal (some_text |> parent |> map_option name) (Some "p");
      assert_equal (some_text |> index_of) 7;

      assert_equal
        (element |> texts)
        ["five"; "three"; "four"; "one"; "six"; "two"; "seven"]);

    ("delete" >:: fun _ ->
      let body = page "list" |> parse $ "body" in
      let ul = body $ "ul" in

      assert_bool "parent" (ul |> R.parent == body);
      assert_equal
        (body |> children |> elements |> to_list |> List.map name)
        ["ul"; "ol"; "p"];

      delete ul;

      assert_equal (ul |> parent) None;
      assert_equal
        (body |> children |> elements |> to_list |> List.map name)
        ["ol"; "p"]);

    ("clear" >:: fun _ ->
      let body = page "list" |> parse $ "body" in
      let original_children = body |> children |> to_list in

      clear body;
      assert_equal (body |> children |> count) 0;

      original_children |> List.iter (fun child ->
        assert_equal (parent child) None));

    ("replace" >:: fun _ ->
      let body = page "list" |> parse $ "body" in
      let ul = body $ "ul" in
      let ol = body $ "ol" in

      replace ul ol;

      assert_equal
        (body |> descendants |> elements |> to_list |> List.map name)
        ["ol"; "li"; "li"; "p"];

      assert_equal
        (ul |> descendants |> elements |> to_list |> List.map name)
        ["li"; "li"; "li"]);

    ("swap" >:: fun _ ->
      let body = page "list" |> parse $ "body" in
      let ul = body $ "ul" in
      let ol = body $ "ol" in

      swap ul ol;

      assert_equal
        (body |> descendants |> elements |> to_list |> List.map name)
        ["ol"; "li"; "li"; "li"; "p"];

      assert_equal (ul |> children |> elements |> count) 2);

    ("wrap" >:: fun _ ->
      let body = page "list" |> parse $ "body" in
      let ul = body $ "ul" in

      let div = create_element "div" in

      wrap ul div;

      assert_equal
        (body |> descendants |> elements |> to_list |> List.map name)
        ["div"; "ul"; "li"; "li"; "li"; "ol"; "li"; "li"; "p"]);

    ("unwrap" >:: fun _ ->
      let body = page "list" |> parse $ "body" in
      let ul = body $ "ul" in

      unwrap ul;

      assert_equal
        (body |> descendants |> elements |> to_list |> List.map name)
        ["li"; "li"; "li"; "ol"; "li"; "li"; "p"];

      assert_equal
        (body |> descendants |> elements |> filter (fun e -> id e <> None)
         |> to_list |> List.map R.id)
        ["one"; "two"; "three"; "four"; "five"]);

    ("mutate-attribute" >:: fun _ ->
      let li = page "list" |> parse $ "li" in

      assert_equal (li |> attribute "id") (Some "one");
      li |> set_attribute "id" "foo";
      assert_equal (li |> attribute "id") (Some "foo");
      li |> delete_attribute "id";
      assert_equal (li |> attribute "id") None;
      assert_equal (li |> attribute "class") (Some "odd"));

    ("mutate-class-list" >:: fun _ ->
      let li = page "list" |> parse $ "li" in

      assert_equal (li |> attribute "class") (Some "odd");
      li |> add_class "odder";
      assert_equal (li |> attribute "class") (Some "odder odd");
      li |> add_class "odd";
      assert_equal (li |> attribute "class") (Some "odder odd");
      li |> remove_class "odd";
      assert_equal (li |> attribute "class") (Some "odder");
      li |> remove_class "odd";
      assert_equal (li |> attribute "class") (Some "odder");
      li |> remove_class "odder";
      assert_equal (li |> attribute "class") None);

    ("case-insensitivity" >:: fun _ ->
      let soup = page "list" |> parse in
      assert_equal (soup |> R.tag "LI" |> name) "li";
      assert_equal (soup $ "LI" |> name) "li");

    ("equal" >:: fun _ ->
      let document1 = "<html><body>\n<p>foo</p>\n<p>bar</p>\n</body></html>" in
      let document2 = "<html><body><p>foo</p><p>bar</p></body></html>" in

      let test ?(not = fun x -> x) message document document' =
        assert_bool message (equal document document' |> not)
      in

      test "self-equal" (parse document1) (parse document1);
      test ~not "whitespace matters" (parse document1) (parse document2);

      test ~not "soup/element" (create_element "a") (create_soup ());
      test ~not "soup/text" (create_text "foo") (create_soup ());
      test ~not "element/text" (create_text "foo") (create_element "a");

      let with_empty_node = parse document2 in
      insert_before (with_empty_node $ "p") (create_text "");
      test "empty node" (parse document2) with_empty_node;

      let with_adjacent_nodes = parse document2 in
      insert_before (with_adjacent_nodes $ "p") (create_text "a");
      insert_before (with_adjacent_nodes $ "p") (create_text "b");
      let without_adjacent_nodes = parse document2 in
      insert_before (without_adjacent_nodes $ "p") (create_text "ab");
      test "adjacent nodes" with_adjacent_nodes without_adjacent_nodes);

    ("equal_modulo_whitespace" >:: fun _ ->
      let document1 = "<html><body>\n<p>foo</p>\n<p>bar</p>\n</body></html>" in
      let document2 = "<html><body><p>foo</p><p>bar</p></body></html>" in

      assert_bool "equal"
        (equal_modulo_whitespace (parse document1) (parse document2)));

    ("pretty_print" >:: fun _ ->
      let document =
        "<html><body class=\"testing\">\n<p>foo</p>\n<p>bar</p>\n</body></html>"
      in

      assert_equal document (document |> parse |> to_string);
      assert_bool "pretty_print"
        (equal_modulo_whitespace
          (parse document) (parse document |> pretty_print |> parse)));
    ("pretty_print_raw" >:: fun _ ->
          let document =
            "<html><head><meta/></head><body class=\"testing\">\n<p>foo</p>\n<p>bar</p>\n</body></html>"
          in
          let expected_document =
            "<html><head><meta></meta></head><body class=\"testing\">\n<p>foo</p>\n<p>bar</p>\n</body></html>"
          in

          assert_equal expected_document (document |> parse |> to_string_raw);
          assert_bool "pretty_print_raw"
            (equal_modulo_whitespace
              (parse document) (parse document |> pretty_print_raw |> parse)))
  ]
]

let () =
  suites |> List.iter run_test_tt_main
