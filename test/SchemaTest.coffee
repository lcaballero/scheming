{expect} = chai

describe 'Scheming', ->
  afterEach ->
    Scheming.reset()

  describe 'create', ->
    it 'should return a constructor function', ->
      Schema = Scheming.create()

      expect(Schema).to.be.a.function

    it 'should invoke normalizePropertyConfig on each key / value pair in the schema config', ->
      normalizePropertyConfig = sinon.spy Scheming, 'normalizePropertyConfig'

      schema =
        name     : 'string'
        age      :
          type     : Number
          required : true
        birthday : Date

      Scheming.create schema

      for k, v of schema
        expect(normalizePropertyConfig).to.have.been.calledWith v, k

      normalizePropertyConfig.restore()

  describe 'Schema', ->
    describe 'defineProperty', ->
      it 'should invoke Scheming.normalizePropertyConfig', ->
        sinon.spy Scheming, 'normalizePropertyConfig'

        Schema = Scheming.create()
        config = { type : 'string', getter : -> true }
        Schema.defineProperty 'name', config

        expect(Scheming.normalizePropertyConfig).to.have.been.called
        expect(Scheming.normalizePropertyConfig).to.have.been.calledWith config, 'name'

        Scheming.normalizePropertyConfig.restore()

      it 'should extend the Schema with the new property', ->
        Schema = Scheming.create()
        Schema.defineProperty 'age',
          type : 'integer'
          setter : (val) -> return val+1
          getter : (val) -> return val * 2

        a = new Schema()
        a.age = 7
        expect(a.age).to.equal 16

    describe 'defineProperties', ->
      it 'should invoke defineProperty for each key value pair', ->
        Schema = Scheming.create()
        sinon.stub Schema, 'defineProperty'

        config = { type : 'string', getter : -> true }
        Schema.defineProperties {a : 'integer', b : config}

        expect(Schema.defineProperty).to.have.been.calledTwice
        expect(Schema.defineProperty).to.have.been.calledWith 'a', 'integer'
        expect(Schema.defineProperty).to.have.been.calledWith 'b', config

        Schema.defineProperty.restore()

    describe 'getProperties', ->
      beforeEach ->
        sinon.stub Scheming, 'normalizePropertyConfig'

      afterEach ->
        Scheming.normalizePropertyConfig.restore()

      it 'getProperty should return a clone of the normalized schema for the given path', ->
        Schema = Scheming.create()
        config = { type : 'string', getter : -> true }
        Scheming.normalizePropertyConfig.returns config

        Schema.defineProperty 'name', {}

        expect(Schema.getProperty('name')).to.eql config
        expect(Schema.getProperty('name')).to.not.equal config

      it 'getProperties should return a clone of the normalized schema', ->
        Schema = Scheming.create()
        config = { type : 'string', getter : -> true }
        config1 = {a:1}
        Scheming.normalizePropertyConfig.returns config1
        Schema.defineProperty 'name', {}
        config2 = {b:2}
        Scheming.normalizePropertyConfig.returns config2
        Schema.defineProperty 'age', {}

        expect(Schema.getProperties()).to.eql {
          name : {a:1}
          age  : {b:2}
        }
        expect(Schema.getProperties().name).to.not.equal config1
        expect(Schema.getProperties().age).to.not.equal config2

    describe 'property', ->
      describe 'assignment', ->
        describe 'of primitive types', ->
          setter = null

          beforeEach ->
            setter = sinon.stub().returns 5
            sinon.stub Scheming.TYPES.Integer, 'identifier'
            sinon.stub Scheming.TYPES.Integer, 'parser'
            Scheming.TYPES.Integer.parser.returns 5

          afterEach ->
            Scheming.TYPES.Integer.identifier.restore()
            Scheming.TYPES.Integer.parser.restore()

          it 'should invoke setter if provided', ->
            Schema = Scheming.create
              age :
                type : 'integer'
                setter : setter

            a = new Schema()
            a.age = 5

            expect(setter).to.have.been.called
            expect(setter).to.have.been.calledWith 5

          it 'should not invoke type parser if identifier returns true', ->
            Scheming.TYPES.Integer.identifier.returns true

            Schema = Scheming.create
              age :
                type : 'integer'

            a = new Schema()
            a.age = 5

            expect(Scheming.TYPES.Integer.parser).to.not.have.been.called

          it 'should invoke type parser if identifier returns false', ->
            Scheming.TYPES.Integer.identifier.returns false

            Schema = Scheming.create
              age :
                type : 'integer'

            a = new Schema()
            a.age = 5.5

            expect(Scheming.TYPES.Integer.parser).to.have.been.called
            expect(Scheming.TYPES.Integer.parser).to.have.been.calledWith 5.5

          it 'should pass results from parser into setter', ->
            Scheming.TYPES.Integer.identifier.returns false
            Scheming.TYPES.Integer.parser.returns 5

            Schema = Scheming.create
              age :
                type : 'integer'
                setter : setter

            a = new Schema()
            a.age = 5.5

            expect(Scheming.TYPES.Integer.parser).to.have.been.called
            expect(Scheming.TYPES.Integer.parser).to.have.been.calledWith 5.5
            expect(Scheming.TYPES.Integer.parser).to.have.returned 5

            expect(setter).to.have.been.called
            expect(setter).to.have.been.calledWith 5

          it 'should treat assignment at time of construction the same as assignment', ->
            Scheming.TYPES.Integer.identifier.returns false

            Schema = Scheming.create
              age :
                type : 'integer'
                setter : setter

            a = new Schema({age : 5.5})

            expect(Scheming.TYPES.Integer.parser).to.have.been.called
            expect(Scheming.TYPES.Integer.parser).to.have.been.calledWith 5.5
            expect(Scheming.TYPES.Integer.parser).to.have.returned 5

            expect(setter).to.have.been.called
            expect(setter).to.have.been.calledWith 5

        describe 'of nested Schemas', ->
          Person = null

          beforeEach ->
            Person = Scheming.create()
            Person = sinon.spy Person

            Person.defineProperties
              name : String
              age : Number
              mother : Person

          it 'invokes constructor on assignment of a plain object', ->
            Lisa = new Person
              name : 'Sarah'
              age : 8

            expect(Person).to.have.been.calledOnce
            Person.reset()

            Lisa.mother = {name : 'Marge', age : 34}

            expect(Person).to.have.been.calledOnce
            expect(Person).to.have.been.calledWith {name : 'Marge', age : 34}
            Person.reset()

            Lisa.mother.mother =
              name : 'Jacqueline'
              age : 80
              mother :
                name : 'Alvarine'
                age  : 102

            expect(Person).to.have.been.calledTwice
            expect(Person).to.have.been.calledWith {name : 'Jacqueline', age : 80, mother: {name : 'Alvarine', age : 102}}
            expect(Person).to.have.been.calledWith {name : 'Alvarine', age : 102}

          it 'does not invoke constructor if assigned object is already instance of correct Schema', ->
            Lisa = new Person
              name : 'Sarah'
              age : 8

            expect(Person).to.have.been.calledOnce

            Marge = new Person
              name : 'Marge'
              age : 34

            Person.reset()

            Lisa.mother = Marge
            expect(Person).not.to.have.been.called

          it 'does invoke constructor if assigned object is instance of a different Schema', ->
            Car = Scheming.create
              make : String
              model : String

            Lisa = new Person
                name : 'Sarah'
                age : 8

            civic = new Car
              make : 'honda'
              model : 'civic'

            Person.reset()

            Lisa.mother = civic

            expect(Person).to.have.been.called
            expect(Person).to.have.been.calledWith civic

      describe 'retrieval', ->
        describe 'of primitive types', ->
          it 'should return the assigned value', ->
            Schema = Scheming.create
              age :
                type : 'integer'

            a = new Schema {age : 5}

            expect(a.age).to.equal 5

          it 'should return the assigned value, accounting for parser', ->
            Schema = Scheming.create
              age :
                type : 'integer'

            a = new Schema {age : 5.5}

            expect(a.age).to.equal 5

          it 'should return the assigned value, accounting for setter', ->
            Schema = Scheming.create
              age :
                type : 'integer'
                setter : (val) -> val * 2

            a = new Schema {age : 5}

            expect(a.age).to.equal 10

          it 'should return the assigned value, accounting for parser, then setter', ->
            Schema = Scheming.create
              age :
                type : 'integer'
                setter : (val) -> val * 2

            a = new Schema {age : 5.5}

            expect(a.age).to.equal 10

          it 'should return the assigned value, accounting for the getter', ->
            Schema = Scheming.create
              age :
                type : 'integer'
                setter : (val) -> val * 2
                getter : (val) -> val - 2

            a = new Schema {age : 5.5}

            expect(a.age).to.equal 8

          it 'should return a clone of the original value, such that mutators will not affect the stored value', ->
            Schema = Scheming.create
              age : Number
              friends : [String]

            a = new Schema {age : 7, friends : ['b', 'c', 'd']}

            # TODO: evidently ++ operator is bypassing the clone?
            # a.age++
            a.friends.push 'e'

            # expect(a.age).to.equal 7
            expect(a.friends).to.eql ['b', 'c', 'd']

          it 'should return a reference in the case of nested schemas', ->
            Car = Scheming.create
              make : String
              model : String

            Person = Scheming.create
              name : String
              car : Car

            civic = new Car {make: 'Honda', model : 'Civic'}
            person = new Person {name : 'bob', car : civic}

            expect(person.car).to.equal civic

        describe 'of Arrays', ->
          it 'should parse child elements of arrays', ->
            Schema = Scheming.create
              ages : [Scheming.TYPES.Integer]

            a = new Schema()

            a.ages = [1, 3.0, '2.5', null]

            expect(a.ages).to.eql [1, 3, 2, NaN]

    describe 'complex array definitions', ->
      it 'should support arrays with defaults, setters, getters', ->
        Contrived = Scheming.create
          arr :
            type : [String]
            default : [2, 3]
            setter : (val) ->
              return _.map val, (num) ->
                return 'a' + num
            getter : (val) ->
              return _.map val, (num) ->
                return num + 'b'

        instance = new Contrived()

        expect(instance.arr).to.eql ['a2b', 'a3b']

        expect(Contrived.validate(instance)).to.be.null

      it 'should support validators', ->
        Contrived = Scheming.create
          arr :
            type : [String]
            default : [2, 3]
            setter : (val) ->
              return val.concat [4]
            getter : (val) ->
              return ([1]).concat val
            required : true
            validate : (val) ->
              return if val.length >= 5 then true else 'Not long enough'

        instance = new Contrived arr : undefined

        errors = Contrived.validate(instance)
        expect(errors.arr).to.exist
        expect(errors.arr).to.have.length 1
        expect(errors.arr[0]).to.match /is required/

        instance = new Contrived()

        errors = Contrived.validate(instance)
        expect(errors.arr).to.exist
        expect(errors.arr).to.have.length 1
        expect(errors.arr[0]).to.match /Not long enough/

    describe 'circular definitions', ->

      it 'should allow two Schemas to reference one another', ->
        Person = Scheming.create 'Person',
          name : String
          cars : ['Schema:Car']

        Car = Scheming.create 'Car',
          model : String
          owner : 'Schema:Person'

        bob = new Person
          name : 'Bob'

        bob.cars = [
          {model : 'Civic', owner : bob}
          {model : '4runner', owner : bob}
        ]

        expect(bob).to.be.instanceOf Person
        expect(bob.cars[0]).to.be.instanceOf Car

    describe 'opts', ->
      describe 'seal', ->
        it 'should allow the model to accept arbitrary keys if it is false', ->
          Person = Scheming.create
            name : String
            age : Number

          lisa = new Person
            name : 'lisa'
            age : 8
            random : 'asdf'

          lisa.stuff = 'ahh!'

          expect(lisa.random).to.eql 'asdf'
          expect(lisa.stuff).to.eql 'ahh!'

        it 'should reject arbitrary keys if it is true', ->
          Person = Scheming.create
            name : String
            age : Number
          , seal : true

          lisa = new Person
            name : 'lisa'
            age : 8
            random : 'asdf'

          lisa.stuff = 'ahh!'

          expect(lisa.random).to.not.exist
          expect(lisa.stuff).to.not.exist

      describe 'strict', ->
        it 'should throw an error rather than parsing values if identifier fails', ->
          Person = Scheming.create
            name : String
            age : Number
          , strict : true

          lisa = new Person()

          expect( ->
            new Person
              name : 9
          ).to.throw 'Error assigning'

          expect( ->
            lisa.age = '8'
          ).to.throw 'Error assigning'

        it 'should not throw an error if identifier passes', ->
          Person = Scheming.create
            name : String
            age : Number
          , strict : true

          lisa = new Person name : 'lisa'

          lisa.age = 8

          expect(lisa.name).to.equal 'lisa'
          expect(lisa.age).to.equal 8