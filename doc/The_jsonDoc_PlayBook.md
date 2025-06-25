# jsonDoc PlayBook
_A little about how to play the jsonDoc way_

## introduction

_jsonDoc_ was created to offer a performant way to operate on [JSON](https://json.org/) data with concise [Delphi](https://www.embarcadero.com/products/delphi) syntax, based on variants and interfaces.

This document provides a set of typical use-cases when handing JSON document structure, and ways to handle them with _jsonDoc_, leveraging the concise syntax, and the tricks _jsonDoc_ got up its sleeve to re-use allocated memory when enumerating series of similar documents.

## create documents

Use the `JSON` function to create a document. You can pass an array of variants, with a sequence of keys and values.

    var
      d:IJSONDocument;
    begin
      d:=JSON;
      //d.ToString gives '{}'
      d:=JSON(['hello','world']);
      //d.ToString gives '{"hello":"world"}'

A variant of VarType varUnknown can also contain any interface reference including `IJSONDocument`, so you could write:

      d:=JSON(['parent',JSON(['child',true])]);
      //d.ToString gives '{"parent":{"child":true}}'

but if it's a fixed structure the code needs to build every time, you can suffix key names with `{` to start an embedded document and use key name `}` to close it:

      d:=JSON(['a{','b{','c',1,'}}','d',2]);
      //d.ToString gives '{"a":{"b":{"c":1}},"d":2}'

If you have a string value holding JSON data, use `Parse` to load the data into an `IJSONDocument` instance:

      d:=JSON.Parse(freshJsonData);
      //or use the function JSON(Variant) overload as shorthand:
      d:=JSON(freshJsonData);

You can call `Parse` on an existing instance, but you need to call `Clear` first to remove the values that were already there (unless that's exactly what you need):

      d.Clear;
      d.Parse(freshJSONData);

`Clear` doesn't deallocate the memory used by keys and values, so when the new document, even only partially, has the same set of keys (including in embedded documents!), it will perform better than creating a fully new instance for every iteration.

## retrieve values

Use `IJSONDocument`'s default indexed property to make it look like you're using an array:

      if d["x"]=1 then
        d["y"]:='hello';

If you expect a certain key to have an embedded document, use the `JSON` function:

    var
      d1,d2:IJSONDocument;
    begin
      d1:=JSON(['a{','b',1,'}']);
      d2:=JSON(d1['a']);
      //d2.ToString='{"b":1}'

If you want to list the keys and values of a document, use `JSONEnum`:

    var
      d:IJSONDocument;
      e:IJSONEnumerator;
    begin
      d:=JSON.Parse(freshJSONData);
      e:=JSONEnum(d);
      while e.Next do
       begin
        displayInfo(e.Key,e.Value);
       end;


If you want to convert the content to something that also supports Variants, use `ToVarArray` to store keys and values in a 2-dimensional array:

    var
      d:IJSONDocument;
      v:Variant;
    begin
      d:=JSON(['x',1,'y',2,'z',3]);
      v:=d.ToVarArray;
      //v[0,0]='x' v[0,1]=1
      //v[1,0]='y' v[1,1]=2
      //v[2,0]='z' v[2,1]=3

## arrays

Variants can have a VarType combined with varArray, jsonDoc tries to support that as seamlessly as possible:

    uses jsonDoc, Variants;
    var
      d:IJSONDocument;
    begin
      d:=JSON(['x',VarArrayOf([1,2,3])]);
      //d.ToString='{"x",[1,2,3]}'
      d:=JSON(['x',VarArrayOf([JSON(['a',1],JSON(['b',1]))])]);
      //d.ToString='{"x",[{"a":1},{"b":2}]}'
      JSON(d['x'][1])['c']:=3;
      //d.ToString='{"x",[{"a":1},{"b":2,"c":3}]}'

Function `JSONEnum` also supports variant arrays:

    var
      v:Variant;
      e:IJSONEnumerator;
    begin
      v:=VarArrayOf(['hello','world']);
      e:=JSONEnum(v);
      while e.Next do
       begin
        displayInfo(e.Key,e.Value);
       end;
      //calls displayInfo('0','hello'); displayInfo('1','world');

By default `VarArrayOf` uses a SafeArray internally for storage, which performs deep copies when assigning the variant values. This costs both time (because of the locking) and memory (because of the duplicates created). Avoid this by using `IJSONArray`. Use the `ja` function to create instances:

      d:=JSON(['x',ja([1,2,3])]);
      //d.ToString='{"x":[1,2,3]}'

A minor inconvenience is that the array indexing into variants no longer works, but that's what the other overload of function `ja` is for:

      d:=JSON(['x',ja([1,2,3])]);
      ja(d['x'])[1]:=99;
      //d.ToString='{"x":[1,99,3]}'

By setting `JSON_UseIJSONArray:=true;` (or compiling with define `JSONDOC_DEFAULT_USE_IJSONARRAY`) you can make _jsonDoc_ use `IJSONArray` instances.

      JSON_UseIJSONArray:=true;
      d:=JSON.Parse('{"x":[1,2,3]}');
      ja(d['x'])[1]:=99;
      //d.ToString='{"x":[1,99,3]}'

And function `JSONEnum` supports `IJSONArray` just fine:

    var
      d:IJSONDocument;
      e:IJSONEnumerator;
    begin
      JSON_UseIJSONArray:=true;
      d:=JSON.Parse('{"x":[100,200]}');
      e:=JSONEnum(d['x']);
      while e.Next do
       begin
        displayInfo(e.Key,e.Value);
       end;
      //calls displayInfo('0',100); displayInfo('1',200);

Both ways of handing arrays can be used together:

    var
      d:IJSONDocument;
      a1,a2:IJSONArray;
    begin
      d:=JSON(['x',VarArrayOf([1,2]),'y',ja([3,4])]);
      a1:=ja(d['x']);  // an IJSONArray instance that works
                       // on the variant array is created for you
      a2:=ja(d['y']);
      a1[1]:=3;
      a2[1]:=7;
      //d.ToString='{"x":[1,3],"y":[3,7]}'

## arrays of documents

If you know on beforehand, a document will contain a (potentially large) array of embedded documents, and you'll be processing them one by one, it makes little sense to have the parser allocate memory for all of the separate documents. In most practical applications, these documents will typically have about the same set of keys but with different values, so it makes extra sense to re-use a single `IJSONDocument` instance and load the subsequent documents into it.

In cases like this, pre-load the parent document with an `IJSONDocArray` instance you get from the `JSONDocArray` function:

    var
      d,d1:IJSONDocument;
      da:IJSONDocArray;
      i:integer;
    begin
      da:=JSONDocArray;
      d:=JSON(['items',da]);
      d.Parse(bigJsonBlobFromNetwork);
      d1:=JSON;
      for i:=0 to da.Count-1 do
       begin
        da.LoadItem(i,d1);
        displayInfo(d1['id'],d1['name']);
       end;

That's the explicit way to enumerate the documents in the array, if you want more concise syntax, you can use the `JSONEnum` overload for `IJSONDocArray` like this:

    var
      a:IJSONDocArray;
      d:IJSONDocArrayEnumerator;
    begin
      JSON(['r',newJSONDocArray(a)]).Parse(bigJsonBlobFromNetwork);
      d:=JSONEnum(a);
      while d.Read do
        displayInfo(d['id'],d['name']);

Also when constructing an array of documents, use an `IJSONDocArray` instance and re-use a single `IJSONDocument` instance to fill the array:

    var
      d,d1:IJSONDocument;
      da:IJSONDocArray;
      s1,s2:string;
    begin
      da:=JSONDocArray;
      d1:=JSON;
      while readItem(s1,s2) do //or any way you prefer to get your data
       begin
        d1['id']:=s1;
        d1['name']:=s2;
        da.Add(d1);
       end;
      d:=JSON(['x',da]);
      //d.ToString starts with '{"x":[{"id":...

## conditional defines

`JSONDOC_JSON_STRICT`
to disallow missing quotes around key names

`JSONDOC_JSON_LOOSE`
to allow missing colons and comma's

`JSONDOC_JSON_PASCAL_STRINGS`
to allow pascal-style strings in JSON data

`JSONDOC_STOREINDENTING`
to make `ToString` write indentation EOL's and tabs

`JSONDOC_THREADSAFE`
to make `IJSONDocument` instances thread-safe

`JSONDOC_DEFAULT_USE_IJSONARRAY`
to set `JSON_UseIJSONArray` to true by default
