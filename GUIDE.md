# jsonDoc
## History
_jsonDoc_ started out as _bsonDoc.pas_ and `IBSONDocument` in the [TMongoWire](https://github.com/stijnsanders/TMongoWire) project. Since it was a solid [JSON](http://json.org/) parser, based on IUnknowns (for the reference counting) and Variants (I really, really hate long lists of overloads for allkinds of types). The need arose to manipulate JSON in several projects unrelated to [MongoDB](https://mongod.org/), so the idea surfaced to have a dedicated project around `IJSONDocument`.

(To complete the move, [TMongoWire](https://github.com/stijnsanders/TMongoWire) has since then replaced `bsonDoc.pas` with `jsonDoc.pas` and separate conversion functions to convert from and to [BSON](http://bsonspec.org/).)

It also explains why the term _document_ is used here and throughout the _jsonDoc_ project for a single set of key-value-pairs instead of _object_ as it was originally called in JavaScript parlance. It also comes in handy to distinguish when other _objects_ are mentioned in relation to programming in an object oriented language to manipulate JSON data.

Design considerations that went into _jsonDoc_ were a succinct syntax — as succinct as I could get it, I really wanted `d[key]:=value;` to do what you would think it does — and a re-use of allocated memory when processing a series of JSON documents that are expected to have roughly a similar set of keys. When handled correctly, this should offer a big performance improvement over other options that would either build up and break down entire structures for each document, or worse: for too much documents at a time.

This goes for entire structures of JSON documents. By virtue of being able to embed JSON documents into each other, you can construct elaborate layered structures to hold complex data. When processing a series of documents that may or may not have children documents, because `IJSONDocument.Clear` propagates to the existing children documents, the memory allocated for keys and values is kept at the ready for the next document. It also propages over arrays or `IJSONDocArray` instances, but that's a whild chapter on its own.

## About JSON

I've been thinking about decoupling this project even further, just like it moved away from BSON, taking the JSON out of it — moving to separate to/from JSON functions — and concentrating on the storage of key-value-pairs, but since these concepts were introduced by JSON, and any project I have used _jsonDoc_ with invariably needs to load and store the data in JSON form, I'll keep it just like it is now.

There are people that consider JSON to have replaced XML, and there are people that consider JSON obsoleted by a number of successors like YAML or TOML or Protocol Buffers, but I won't go that far. Just as XML took some time to mature and find it's place in the world (and maybe hit a peak?), JSON took the world project by project, and may not have peaked yet. I have no way of telling.

By getting the balance between human and computer readability just right, by offering great flexibility with a syntax that is just strict enough, and steering clear of ending up too verbose, JSON did a number of things right — other than being there at just the right time for the right people to pick it up — I dare to guess it's still got a nice future ahead of itself.

## First steps

The easiest way to use _jsonDoc_ is adding `jsonDoc.pas` to your project, and adding `jsonDoc` to the uses clause of a unit. Declare a variable of type `IJSONDocument` and use the `JSON` function to generate an instance. Either have it call `Parse` for you by passing in a string, or call `Parse` yourself.

    uses jsonDoc, Variants;

    var
      d:IJSONDocument;
    begin
      d:=JSON('{"x":2}');
      WriteLn(d['x']); // 2

      d.Parse('{"z":true,"x":3}');
      WriteLn(d['x']); // 3

      d.AsString:='{"x":4}';
      WriteLn(d['x']); // 4
    end;

The `JSON` function has a number of overloads. There's one that takes an array of variants, where you can provide a series of key-value-pairs to construct a new document. It's not really as neat as the JavaScript object notation where the idea for JSON originated from (what's in a name!), but this has just about the same succinctness of syntax. It doesn't switch between `:` and `,`, so with all commas you need to keep track of what's a key and what is a value, but you can use clever indentation for that!

    var
      d:IJSONDocument;
    begin
      d:=JSON([
        'a',1,
        'b',true,
        'z',JSON(['a',2.3])
        ]);
      d['b']:='!';
      WriteLn(d.AsString); // {"a":1,"b":"!","z":{"a":2.3}}
    end;

Is has one more trick up its sleeve: the embedded `JSON` call above does some work on variants and pointers for it to get ready for the argument list of the outer call. You can avoid this by using `{` suffixes to the keys to start an embedded document. Use a single `'}'` value to close an embedded document.

    d:=JSON(['a{','b',1,'}','c',2]);
    WriteLn(d.AsString); //  {"a":{"b":1},"c":2}

If you need to access embedded documents, you'll need to access the `IJSONDocument` instances stored in the variant values of the parent document. There is a handy overload of the `JSON` function to just that:

    var
      d1,d2:IJSONDocument;
    begin
      d1:=JSON('{"x":{"a":"!"}}');

      d2:=JSON(d1['x']);

      WriteLn(d2['a']); // !
    end;

If you know the structure of the documents on beforehand, you can pre-load a `IJSONDocument` instance

    var
      d1,d2:IJSONDocument;
    begin
      d2:=JSON;
      d1:=JSON(['x',d2]);

      d1.Parse('{"x":{"a":"!!"}}');

      WriteLn(d2['a']); // !!
    end;

In case you were wondering where the `Create` and `Free` calls are, that's the great thing about using interface pointers that all inherit from `IUnknown`: reference counting does the object lifetime management for you. If you're in a longer block of code and are sure you no longer need a document, you can do `d:=nil;` to call the desctructor, if `d` is the only reference to the instance.

If you really need to get the best possible performance, and are worried that the system wide locks of the reference counting could slow things down, don't worry, the default implementation of `IJSONDocument` have locking disabled. This makes them unsafe for use in a multi-threaded environment, though. If you need to, you should do your own locking, or add a project define `JSONDOC_THREADSAFE`. There are more defines to fine-tune how _jsonDoc_ behaves, see below.

## IJSONEnumerator

If you need to process all keys in a JSON document, you'll need a `IJSONEnumerator` instance. Use the `JSONenum` function to get one. It works somewhat like an ADO recordset, except `MoveNext` and `EOF` are combined in a single `Next` that returns if 'data is available'. Use the `Key` and `Value` properties to examine the contents.

    var
      d:IJSONDocument;
      e:IJSONEnumerator;
    begin
      d:=JSON('{"x":1,"y":2,"z":3}');
      e:=JSONEnum(d);
      while e.Next do
        WriteLn(e.Key+'='+VarToStr(e.Value)); // x=1 y=2 z=3
    end;

Remember the `JSON` function? It comes in handy here as well when you need to examine embedded documents.

    var
      d:IJSONDocument;
      e:IJSONEnumerator;
    begin
      d:=JSON(['name','John Doe','address{','street','Main Street']);
      e:=JSONEnum(d);
      while e.Next do
        if e.Key='address' then
          WriteLn(JSON(e.Value)['street']); // Main Street
    end;

## Arrays

By default _jsonDoc_ uses variant arrays to store JSON arrays. There are ways around this, but if you need to quick-and-dirty work on JSON arrays, some standard variant array functions come in handy.

    var
      d:IJSONDocument;
      v:Variant;
      i:integer;
    begin
      d:=JSON(['x',VarArrayOf([2,true,JSON(['x',1])])]);

      WriteLn(d.AsString); // {"x":[2,true,{"x":1}]}
      WriteLn(d['x'][0]); // 2

      d.Parse('{"a":[5,6,7,8]}');
      v:=d['a'];
      for i:=VarArrayLowBound(v,1) to VarArrayHighBound(v,1) do
        WriteLn(v[i]); // 5 6 7 8
    end;

You could also use an `IJSONArray` object to do this for you. Use the `ja` function to get one based on a variant value.

    var
      d:IJSONDocument;
      a:IJSONArray;
      i:integer;
    begin
      d:=JSON('{"a":[5,6,7,8]}');
      a:=ja(d['a']);
      for i:=0 to a.Count-1 do
        WriteLn(a[i]); // 5 6 7 8
    end;

And even though the `IJSONArray` object you get, also implements `IJSONEnumerator` (and `e:=JSONEnum(ja(d['a'])));` would work), you can skip it altogether.

    var
      d:IJSONDocument;
      e:IJSONEnumerator;
    begin
      d:=JSON('{"a":[5,6,7,8]}');
      e:=JSONEnum(d['a']);
      while e.Next do
        WriteLn(e.Value); // 5 6 7 8
    end;

## IJSONDocArray

Larger JSON data sets typically have arrays of documents. If you'll be processing these one by one, it makes no sense to first parse the entire set and allocate memory for it. That's where the `IJSONDocArray` interface comes in. If the `IJSONDocument.Parse` procedure sees a pre-existing `IJSONDocArray` instance, it is used to hold the documents of the array without fully parsing and unloading them. It uses a list of indexes into the JSON data, to parse each document at the time you want to access it, ideally in an existing `IJSONDocument` instance, that may already hold a similar — if not the same — set of keys, so no time is wasted allocating memory for the values.

    var
      l:IJSONDocArray;
      d,f:IJSONDocument;
      i:integer;
    begin
      l:=JSONDocArray;
      d:=JSON(['items',l]);

      //d.Parse(...
      
      f:=JSON;
      for i:=0 to l.Count-1 do
       begin
        l.LoadItem(i,f);
        WriteLn(f.AsString);
       end;
     end;

By using the same instance of `IJSONDocument` for a sequence of calls to `LoadItem` the magic happens, but is mostly hidden from view. The first document in the array will cause the most common keys to get memory allocated for them, but subsequent documents will use the same memory. Only when other documents have less common keys, more memory will be allocated. This also works for embedded documents.

    var
      a:IJSONDocArray;
      b,c:IJSONDocument;
      i:integer;
    begin
      c:=JSON;
      b:=JSON(['x',c]);
      a:=JSONDocArray([JSON('{"x":{"y":11}'),JSON('{"x":{"y":22}}')]);
      for i:=0 to a.Count-1 do
       begin
        a.LoadItem(i,b);
        WriteLn(c['y']); // 11 22
       end;
    end;

This also works over other embedded document arrays that may exist deeper in the structure. (`LoadItem` calls `IJSONDocument.Clear` before `Parse`, and this gets _propagated down_ into any `IJSONDocument` and `IJSONDocArray` instances already present.)

    var
      a,c:IJSONDocArray;
      b:IJSONDocument;
      i:integer;
    begin
      Memo1.Clear;
      c:=JSONDocArray;
      b:=JSON(['x',c]);
      a:=JSONDocArray([JSON('{"x":[{"y":1},{"z":2}]}'),JSON('{"x":[]}')]);
      for i:=0 to a.Count-1 do
       begin
        a.LoadItem(i,b);
        WriteLn(c.Count); // 2 0
       end;
    end;

**Attention:** There's a big ugly secret about how `IJSONDocArray` works, and that's that it uses strings with JSON data to store the elements of the array. This means that if you make changes to an object, the changes are not persisted in the array, unless you assign the modified document back into the same array index.

    var
      a:IJSONDocArray;
      d:IJSONDocument;
    begin
      a:=JSONDocArray([JSON(['x',1])]);
      JSON(a[0])['x']:=2;
      WriteLn(a.AsString);// [{"x":1}] still, change is lost
      d:=JSON(a[0]);
      d['x']:=2;
      a[0]:=d;
      WriteLn(a.AsString);// [{"x":2}]
    end;

If you're handling the JSON data in strings, and want to add them to an `IJSONDocArray`, you can avoid a parse-and-persist-to-string round trip using `AddJSON`. The other way round, you can access elements directly with `GetJSON`, also `AsString` builds the complete array in `[{...},{...}...]` syntax.

## JSONEnumSorted

The default `IJSONEnumerator` offers the keys in the order they are present in the original data. If you need to enumerate the keys of a JSON document, but need them in sorted order, it's tempting to store them in a temporary list and sort that before doing further processing on it. If you know the default `IJSONDocument` implementation has an internal sorted list of available keys to speed up key lookup, I hope you can understand that would be duplicate effort to use a second list of keys and do the sorting again.

To access the internal sorted list of keys, use the `JSONEnumSorted` function. It also offers an `IJSONEnumerator` implementation, but one that uses the internal sorted order, not the original document order.

## Loading/saving JSON from/to file

_jsonDoc_ itself doesn't have specific functions to load JSON data from files, or store JSON data into files. You're free to use the many options available to you. For example, the unit `System.IOUtils` declares class procedures `TFile.ReadAllText` and `TFile.WriteAllText`. For maximal interoperability, it's advised to use UTF8 to store JSON files.

    var
      d:IJSONDocument;
    begin
      d:=JSON(TFile.ReadAllText('demo1.json'));
      d['x']:=true;
      TFile.WriteAllText('demo2.json',d.AsString,TEncoding.UTF8);
    end;

## UseIJSONArray, UseIJSONDocArray

...

## Additional Defines

Add these defines to the project compiler configuration to modify the behaviour of _jsonDoc_.

### JSONDOC_JSON_STRICT
to disallow missing quotes around key names

### JSONDOC_JSON_LOOSE
to allow missing colons and comma's

### JSONDOC_JSON_PASCAL_STRINGS
to allow pascal-style strings

### JSONDOC_P2
to combine `JSONDOC_JSON_LOOSE` and `JSONDOC_JSON_PASCAL_STRINGS`

### JSONDOC_STOREINDENTING
to make `AsString` write indentation EOL's and tabs

### JSONDOC_THREADSAFE
to make `IJSONDocument` instances thread-safe

### JSONDOC_DEFAULT_USE_IJSONARRAY
to set `JSON_UseIJSONArray` to true by default

### JSONDOC_DEFAULT_USE_IJSONDOCARRAY
to set `JSON_UseIJSONDocArray` to true by default