# resty-test-gui
Simple tools for easy testing REST API endpoints

## Purpose

The purpose of the application is to provide simple tools for testing REST API endpoints.

---

## Usage

### **Create a Descriptor File**
- Create a YAML file that adheres to the OpenAPI 3.0 standard and describes your API endpoints.
- By default, the system uses the `default_config.yaml` file.
- To use a different descriptor, use the `config` parameter:
  ```
  http://localhost:8880/test-ui?config=echo
  ```

### **Direct Form Access**
You can directly access the input form using query parameters:
```
http://localhost:8880/test-ui?method=post&path=echo&config=echo
```

---

## Configuration

### **Dropdown Control Customization**
Define options for a dropdown as follows:
```yaml
- name: select
  in: query
  schema:
    type: string
    enum: [ "apple", "banana", "lemon" ]
```

#### **Add Labels to Options**
```yaml
- name: select
  in: query
  schema:
    type: string
    enum: [ "apple", "banana", "lemon" ]
    x-tui-enum: [ "Apple", "Banana", "Lemon or Orange" ]
```

#### **Change Type to `radio`**
```yaml
- name: select
  in: query
  schema:
    type: string
    enum: [ "apple", "banana", "lemon" ]
    x-tui-enum: [ "Apple", "Banana", "Lemon or Orange" ]
    x-tui-type: radio
```

#### **Adjust the Style**
```yaml
- name: select
  in: query
  schema:
    type: string
    enum: [ "apple", "banana", "lemon" ]
    x-tui-style: width:140px;
```

#### **Modify the Label**
```yaml
x-tui-label: My test control
```

#### **Change to `checkbox` Type**
Display `enum` items as a `checkbox-group`:
```yaml
x-tui-type: checkbox
```

---

### **Security Token Configuration**
Enable the `Bearer` token in the configuration:
```yaml
post:
  ...
  security:
    - BearerAuth: []  # Requires Bearer token
```

---

## File Structure

### **Test-UI Application Files**
```
.
├── conf
│   └── nginx-local.conf
├── logs
└── test-ui
    ├── default_config.yaml
    ├── gen-ui
    │   ├── generator.lua
    │   ├── tmpl_form.html
    │   ├── tmpl_item.html
    │   └── tmpl_list.html
    └── rest
        └── init.lua
```


